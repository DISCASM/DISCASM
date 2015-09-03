#!/usr/bin/env python

import os, sys, re
import pysam
import threading

usage = "\n\n\tusage: " + sys.argv[0] + " Chimeric.out.junction left.fq right.fq\n\n"

if len(sys.argv) < 4:
    print >>sys.stderr, usage
    sys.exit(1)


chimeric_junction_file = sys.argv[1]
left_fq_filename = sys.argv[2]
right_fq_filename = sys.argv[3]

MIN_PCT_ALIGNED = float(80)


def main():

    want_pairs = set()
    for line in open(chimeric_junction_file):
        x = line.split("\t")
        frag_name = x[9]
        want_pairs.add(frag_name)
    
    
    

    left_fq_extracted_filename = os.path.basename(left_fq_filename) + ".extracted.fq"
    right_fq_extracted_filename = os.path.basename(right_fq_filename) + ".extracted.fq"

    left_fq_extraction_thread = Unkept_read_fq_extractor(want_pairs, left_fq_filename, left_fq_extracted_filename)
    right_fq_extraction_thread = Unkept_read_fq_extractor(want_pairs, right_fq_filename, right_fq_extracted_filename)
    
    left_fq_extraction_thread.start()
    right_fq_extraction_thread.start()

    num_failed = 0
    for t in (left_fq_extraction_thread, right_fq_extraction_thread):
        t.join()
        if not t.success:
            num_failed += 1
            print >>sys.stderr, "Error extracting reads from file: " + t.input_fq_filename



    sys.exit(num_failed)
    

    

class Unkept_read_fq_extractor (threading.Thread):

    thread_counter = 0

    def __init__(self, keep_set, input_fq_filename, output_fq_filename):
        threading.Thread.__init__(self)

        self.keep_set = keep_set
        self.input_fq_filename = input_fq_filename
        self.output_fq_filename = output_fq_filename

        Unkept_read_fq_extractor.thread_counter += 1
        self.id = Unkept_read_fq_extractor.thread_counter

        self.success = False
        
        

    def run(self):
        ## do the extraction

        ofh = open(self.output_fq_filename, 'w')
        
        fq_reader = pysam.FastqFile(self.input_fq_filename)
        for fq_entry in fq_reader:
            read_name = fq_entry.name
            read_name = re.sub("/[12]$", "", read_name)
            if read_name in self.keep_set:
                ofh.write( "\n".join(["@" + fq_entry.name,
                                      fq_entry.sequence,
                                      "+",
                                      fq_entry.quality]
                                     ) + "\n")
        
        ofh.close()

        self.success = True


        



main()


