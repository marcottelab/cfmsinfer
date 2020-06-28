#! /bin/bash
CONFIG=$1
source $CONFIG

while read exp
  do
    for feat in ${exp%.wide}*feat
      do

        rm -f logs/log_alphabetize_${feat##*/}
        rm -f errors/error_error_alphabetize_${exp##*/}
 
        echo "python $PCM_DIR/protein_complex_maps/features/alphabetize_pairs2.py --feature_pairs $feat --outfile ${feat}.ordered --sep ',' --chunksize $CHUNKSIZE  > logs/log_alphabetize_${feat##*/} 2> errors/error_alphabetize_${feat##*/}" 
      done

  done < $EXPLIST > records/record_alphabetize_COMMANDS.sh 

# cat records/record_alphabetize_COMMANDS.sh | parallel -j30
