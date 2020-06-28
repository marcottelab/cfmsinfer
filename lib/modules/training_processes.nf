#!/usr/bin/env nextflow
// Build feature matrix from calculated features
process cfmsinfer_scan {

  // Don't copy input file to work directory
  scratch true

  tag { scan_parameters }

  publishDir "${params.output_dir}", mode: 'link'

  input:
  path featmat_labeled1


  output:
  path "pipeline.py"
  


  script:

  """
  CLASSIFIERS_FORMATTED=\$(cat $params.classifiers_to_scan | tr '\n' ' ')

  mkdir tpot.tmp
  python /project/cmcwhite/github/run_TPOT/train_TPOT.py --training_data featmat_labeled1 --outfile pipeline.py --classifier_subset \$CLASSIFIERS_FORMATTED --id_cols 0 --n_jobs $params.n_jobs --generations $params.generations --population_size $params.population --labels -1 1 --temp_dir training/tpot.tmp

  """
}


// Train with parameters from scan
process cfmsinfer_train {

  // Don't copy input file to work directory
  scratch false

  tag { train_model }

  publishDir "${params.output_dir}", mode: 'link'

  input:
  path pipeline
  path featmat_labeled1

  output:
  path "tpot_fitted_model.p"
  
  script:
  """
  python /project/cmcwhite/github/run_TPOT/train_test_model2.py --training_infile $featmat_labeled1 --exported_pipeline $pipeline --id_cols 0 --output_basename tpot
  """
}


// Apply model to all interactions
process cfmsinfer_score {

  // Don't copy input file to work directory
  scratch false

  tag { apply_model }

  publishDir "${params.output_dir}", mode: 'link'publishDir "${params.output_dir}", mode: 'link'

  input:
  path model
  path featmat

  output:
  path "scored_interactions"
  

  script:

  """
  python /project/cmcwhite/github/run_TPOT/tpot_predict.py --datafile $featmat --serialized_model $model --outfile scored_interactions --id_cols 0

  """
}


