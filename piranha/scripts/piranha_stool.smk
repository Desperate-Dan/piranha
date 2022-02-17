#!/usr/bin/env python3
import os
import collections
from Bio import SeqIO
import yaml

from piranha.analysis.stool_functions import *
from piranha.report.make_report import make_sample_report
from piranha.utils.log_colours import green,cyan
from piranha.utils.config import *
##### Target rules #####
"""
input files
os.path.join(config[KEY_OUTDIR],PREPROCESSING_SUMMARY)
os.path.join(config[KEY_OUTDIR],"hits.csv")
os.path.join(config[KEY_OUTDIR],SAMPLE_COMPOSITION)
"""
rule all:
    input:
        os.path.join(config[KEY_OUTDIR],"consensus_sequences.fasta"),
        expand(os.path.join(config[KEY_OUTDIR],"{barcode}","consensus_sequences.fasta"), barcode=config[KEY_BARCODES])

rule files:
    params:
        composition=os.path.join(config[KEY_OUTDIR],SAMPLE_COMPOSITION),
        summary=os.path.join(config[KEY_OUTDIR],PREPROCESSING_SUMMARY)


rule generate_consensus_sequences:
    input:
        snakefile = os.path.join(workflow.current_basedir,"consensus.smk"),
        yaml = os.path.join(config[KEY_TEMPDIR],PREPROCESSING_CONFIG),
        prompt = os.path.join(config[KEY_TEMPDIR],"{barcode}","reference_groups","prompt.txt")
    params:
        barcode = "{barcode}",
        outdir = os.path.join(config[KEY_OUTDIR],"{barcode}"),
        tempdir = os.path.join(config[KEY_TEMPDIR],"{barcode}")
    threads: workflow.cores*0.5
    log: os.path.join(config[KEY_TEMPDIR],"logs","{barcode}_consensus.smk.log")
    output:
        fasta = os.path.join(config[KEY_OUTDIR],"{barcode}","consensus_sequences.fasta"),
        csv= os.path.join(config[KEY_OUTDIR],"{barcode}","variants.csv"),
        json = os.path.join(config[KEY_OUTDIR],"{barcode}","variation_info.json")
    run:
        print(green(f"Generating consensus sequences for {params.barcode}"))
        shell("snakemake --nolock --snakefile {input.snakefile:q} "
                    "--forceall "
                    "{config[log_string]} "
                    "--configfile {input.yaml:q} "
                    "--config barcode={params.barcode} outdir={params.outdir:q} tempdir={params.tempdir:q} "
                    "--cores {threads} &> {log:q}")

rule gather_consensus_sequences:
    input:
        composition = rules.files.params.composition,
        fasta = expand(os.path.join(config[KEY_OUTDIR],"{barcode}","consensus_sequences.fasta"), barcode=config[KEY_BARCODES])
    output:
        fasta = os.path.join(config[KEY_OUTDIR],"consensus_sequences.fasta")
    run:
        gather_fasta_files(input.composition, config[KEY_BARCODES_CSV], input.fasta, output[0])

rule generate_report:
    input:
        consensus_seqs = rules.generate_consensus_sequences.output.fasta,
        variation_info = rules.generate_consensus_sequences.output.json,
        yaml = os.path.join(config[KEY_TEMPDIR],PREPROCESSING_CONFIG)
    params:
        outdir = os.path.join(config[KEY_OUTDIR],"barcode_reports"),
        barcode = "{barcode}",
    output:
        html = os.path.join(config[KEY_OUTDIR],"barcode_reports","{barcode}_report.html")
    run:
        with open(input.yaml, 'r') as f:
            config_loaded = yaml.safe_load(f)

        make_sample_report(output.html,input.variation_info,input.consensus_seqs,params.barcode,config_loaded)


