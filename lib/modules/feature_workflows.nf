#!/usr/bin/env nextflow

include { corr_process } from './feature_processes'
include { rescale_process } from './feature_processes'
include { alph_process } from './feature_processes'


// Calculate correlation and distance-based features
workflow cfmsinfer_corr {
 
   main:

   // Full path to each elution file provided in a text file
   if (params.input_elution_file){ 
    Channel.fromPath(params.input_elution_file)
        .splitText()
        .map { file(it.replaceFirst(/\n/,'')) }
        .set { elutions }
   }
   // Locate input elutions based on pattern matching
   else {

     elutions_path = params.input_elution_pattern
 
     println(elutions_path)

     Channel
       .fromPath( elutions_path, checkIfExists: true )
       .set { elutions }

     println(elutions)

   }
    Channel
      .from( "pearsonR", "spearmanR", "euclidean", "braycurtis" )
      .set { corrs }

    elutions
      .combine(corrs)
      .set { elutions_and_corrs }

    output_corrs = corr_process(elutions_and_corrs) 
    output_corrs = rescale_process(output_corrs)
    output_corrs = alph_process(output_corrs, ",")

    features = output_corrs.collect()

  emit:
    features

}



workflow load_features {
    main:
         // Replace with features = load_features()   
         if ( params.input_features_file ) {
            Channel.fromPath( params.input_features_file, checkIfExists: true )
             .splitText() 
             .map { file( it.replaceFirst(/\n/, '' )) }    
             .set { features }                                         
         }
         else if ( params.input_features_pattern ) { 
           Channel.fromPath( params.input_features_pattern, checkIfExists: true )
            .set { features }
         }
         else {
           println "Entering pipeline at step 2 requires either parameter features_pattern or features_file"
         System.exit(1)
         }
         
         features = features.collect()

    emit:
      features
}


