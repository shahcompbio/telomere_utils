version 1.0


task SamtoolsCollate{
    input{
        File bamfile
    }
    command<<<
        samtools collate -u ~{bamfile} tempdir/output
    >>>
    output{
        File bamfile = "tempdir/output.bam"
    }

}


task SplitSam{
    input{
        File bamfile
    }
    command<<<
        telomere_utils split_bam --infile ~{bamfile} --outdir tempdir/
    >>>
    output{
        Array[File] bamfiles = glob("tempdir/*.sam")
    }
}

task ExtractReads{
    input{
        File bamfile
        File sample_id
        Float perc_threshold = 0.85
        Int mapping_quality = 30
        Int telomere_length_threshold = 36
    }
    command<<<
        telomere_utils extract_reads --input ~{bamfile} \
        --outbam output.bam --outcsv output.csv \
        --sample_id ~{sample_id} --perc_threshold ~{perc_threshold} \
        --mapping_quality ~{mapping_quality} \
        --telomere_length_threshold ~{telomere_length_threshold}
    >>>
    output{
        File outbam = "output.bam"
        File outcsv = "output.cssv"
    }
}

task MergeCsv{
    input{
        Array[File] inputs
    }
    command<<<
        telomere_utils merge_files \
        --inputs ~{sep=" "inputs} --output output.csv.gz
    >>>
    output{
        File out_csv = "output.csv.gz"
    }
}


task GetOverlap{
    input{
        File normal_bam
        File normal_csv
        File tumour_csv
        Int binsize = 1000
    }
    command<<<
        telomere_util get_overlap \
        --normal_bam ~{normal_bam} --normal_data ~{normal_csv} \
        --tumour_data ~{tumour_csv} --output overlapping.csv.gz \
        --bin_counts bin_counts.csv.gz --binsize ~{binsize}
    >>>
    output{
        File outfile = "overlapping.csv.gz"
        File bin_counts = "bin_counts.csv.gz"
    }
}




workflow TelomereWorkflow{
    input{
        File normal_bam
        File tumour_bam
        String normal_sample_id
        String tumour_sample_id
        Float perc_threshold = 0.85
        Int mapping_quality = 30
        Int telomere_length_threshold = 36
        Int binsize = 1000
    }

    task SamtoolsCollate as normal_collate{
        input:
            bamfile = normal_bam
    }
    task SamtoolsCollate as tumour_collate{
        input:
            bamfile = tumour_bam
    }
    task SplitSam as normal_split{
        input:
        bamfile = normal_collate.bamfile
    }
    task SplitSam as tumour_split{
        input:
        bamfile = tumour_collate.bamfile
    }

    scatter (bamfile in  normal_split.bamfiles){
        task ExtractReads as extract_normal{
            input:
                bamfile = bamfile,
                sample_id = normal_sample_id,
                perc_threshold=perc_threshold,
                mapping_quality=mapping_quality,
                telomere_length_threshold=telomere_length_threshold
        }
    }

    scatter (bamfile in  tumour_split.bamfiles){
        task ExtractReads as extract_tumour{
            input:
                bamfile = bamfile,
                sample_id = tumour_sample_id,
                perc_threshold=perc_threshold,
                mapping_quality=mapping_quality,
                telomere_length_threshold=telomere_length_threshold
        }
    }

    task MergeCsv as merge_normal{
        input:
            inputs = extract_normal.outcsv
    }
    task MergeCsv as merge_tumour{
        input:
            inputs = extract_tumour.outcsv
    }

    task GetOverlap as overlap{
        input:
            normal_bam = normal_bam,
            normal_data = merge_normal.out_csv,
            tumour_data = merge_tumour.out_csv,
            binsize=binsize
    }

    output{
        File tumour_data = merge_tumour.out_csv
        File normal_data = merge_normal.out_csv
        File overlap_data = overlap.outfile
        File bin_counts = overlap.bin_counts
    }

}
