import os
import collections
from Bio import SeqIO
import yaml

from piranha.analysis.clean_gaps import *

from piranha.analysis.consensus_functions import *
from piranha.utils.log_colours import green,cyan
from piranha.utils.config import *


BARCODE = config[KEY_BARCODE]
SAMPLE = str(config[KEY_SAMPLE])
REFERENCES = config[BARCODE]


rule all:
    input:
        os.path.join(config[KEY_TEMPDIR],"variation_info.json")

rule files:
    params:
        ref=os.path.join(config[KEY_TEMPDIR],"reference_analysis","{reference}.ref.fasta"),
        cns=os.path.join(config[KEY_TEMPDIR],"reference_analysis","{reference}.merged_cns.fasta"),
        bam = os.path.join(config[KEY_TEMPDIR],"reference_analysis","{reference}.merged_cns.bam")

rule get_variation_info:
    input:
        variant_file = os.path.join(config[KEY_TEMPDIR],"variants.csv"),
        ref = expand(rules.files.params.ref, reference=REFERENCES),
        bams = expand(rules.files.params.bam, reference=REFERENCES)
    output:
        json = os.path.join(config[KEY_TEMPDIR],"variation_info.json")
    run:
        # split this by ref group, but merge cns info per ref group
        variation_dict = {}
        all_var_dict = parse_variant_file(input.variant_file)

        for reference in REFERENCES:

            variation_dict[reference] = {"variation":[],"coocc":[]}
            if "Sabin" in reference:
                ref = os.path.join(config[KEY_TEMPDIR],"reference_analysis",f"{reference}.ref.fasta")
                bamfile = os.path.join(config[KEY_TEMPDIR],"reference_analysis",f"{reference}.merged_cns.bam")
            else:
                #not the ref, should be cns
                ref = os.path.join(config[KEY_TEMPDIR],"reference_analysis",f"{reference}.ref.fasta")
                bamfile = os.path.join(config[KEY_TEMPDIR],"reference_analysis",f"{reference}.merged_cns.bam")
            shell(f"samtools faidx {ref}")

            ref_dict = ref_dict_maker(ref)

            var_dict = all_var_dict[reference]
            
            # just run pileupper once for both coocurance and variation processing
            variation_json,read_vars = pileupper(bamfile,ref_dict,var_dict)
            variation_dict[reference]["variation"] = variation_json

            # getting cooccurance info here now
            if var_dict:
                variation_dict[reference]["coocc"] = calculate_coocc_json(var_dict,read_vars)
            else:
                variation_dict[reference]["coocc"] = []

        with open(output.json, "w") as fw:
            json.dump(variation_dict, fw)
