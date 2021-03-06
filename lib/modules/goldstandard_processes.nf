#!/usr/bin/env nextflow

// Split into test and train
process split_traintest {

  // copy input file to work directory
  scratch false

  input:
  file goldstandard_complexes

  tag { goldstandard }

  publishDir "${params.output_dir}", mode: 'link'

  output:
  path "goldstandard_filt.train_ppis.ordered", emit: 'postrain'
  path "goldstandard_filt.test_ppis.ordered", emit: 'postest'
  path "goldstandard_filt.neg_train_ppis.ordered", emit: 'negtrain'
  path "goldstandard_filt.neg_test_ppis.ordered", emit: 'negtest'
  path "goldstandard_filt.all_train.txt", emit: 'postraincomplexes'
  path "goldstandard_filt.all_test.txt", emit: 'postestcomplexes'
 

  script:
  """
   # Filter and organize subcomplexes
     python $params.protein_complex_maps_dir/protein_complex_maps/preprocessing_util/complexes/complex_merge.py --cluster_filename $goldstandard_complexes --output_filename goldstandard_filt.txt --merge_threshold $params.merge_threshold --complex_size_threshold $params.complex_size_threshold  --remove_largest --remove_large_subcomplexes

   # Split complexes to training and test complexes 
   python $params.protein_complex_maps_dir/protein_complex_maps/preprocessing_util/complexes/split_complexes2.py --input_complexes goldstandard_filt.txt


   # Figure out where commas are coming from
   sep=" " 
   for gs in goldstandard_filt.*_ppis.txt;
   do
     sed -i 's/\t/ /' \$gs
     python $params.protein_complex_maps_dir/protein_complex_maps/features/alphabetize_pairs_chunks.py --feature_pairs \$gs --outfile \${gs%.txt}.ordered --sep "\$sep" --chunksize 1000
   done

  """
}

// Generate negatives from observed proteins
process get_negatives_from_observed {

  // copy input file to work directory
  scratch true

  tag { negative_from_observed }

  input:
  path featmat
  path postrain
  path postest

  publishDir "${params.output_dir}", mode: 'link'

  output:
  path "negtrain.randsort", emit: 'negtrain'
  path "negtest.randsort", emit: 'negtest'



  script:
  """
  # "all ID pairs from the feature matrix (remove header with tail)"
  awk -F',' '{print \$1}' $featmat |  tail -n +2 > identifiers_infeatmat

  # "Remove any interactions that are in the positive set"
  cat identifiers_infeatmat | grep -vFf $postrain | grep -vFf $postest > neg_pool

  sort -R neg_pool > neg_pool.randsort                            

  split --number=l/2 neg_pool.randsort 
  mv xaa negtrain.randsort 
  mv xab negtest.randsort
  

  """

}


// Limit number of negatives in each set
process limit_negatives {

  // Don't copy input file to work directory
  scratch false

  tag { limit_negatives }

  input:
  path negtrain
  path negtest
   
  publishDir "${params.output_dir}", mode: 'link'


  output:
  path "negtrain", emit: 'negtrain'
  path "negtest", emit: 'negtest'

  script:
  """
  head *    

  sort -R $negtrain | head -$params.negative_limit > negtrain
  sort -R $negtest | head -$params.negative_limit > negtest


  """

}

/// Create mapping between training interactions and complexes for GroupKFold cross validation

process get_cv_groups {

  input:
  path postrain
  path postraincomplexes
  path negtrain

  publishDir "${params.output_dir}", mode: 'link'

  output:
    path "traincomplexgroups"

  script:
  """
  echo "ID1,ID2,Group" > traincomplexgroups
 
  #Assign all positive ppi to a complex 
  #This allows GroupKFold cross validation to
  #  avoid having complex members in different cv sets
  #If ppi in multiple training complexes, given first complex id
  while read ppi;
  do
  
    p1=`echo \$ppi | cut -d' ' -f1`
    p2=`echo \$ppi | cut -d' ' -f2`
  
    linenum=`grep -n \$p1 $postraincomplexes | grep \$p2 | cut -d":" -f1 | head -1`
    echo "\$p1,\$p2,\$linenum"  >> traincomplexgroups
  
  done < $postrain
  
  numcomplexes=`wc -l < $postraincomplexes`

  #Assign all negative ppi a group number 
  #   not overlapping train complex numbers
  echo "test"
  awk -v n=\$numcomplexes 'BEGIN { OFS = "," }{print \$1,\$2,NR+n}' $negtrain >> traincomplexgroups   
  echo "trash"
  """
 

 
}


