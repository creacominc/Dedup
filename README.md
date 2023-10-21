# Dedup
dedup swift project


Next Step:  Increase efficiency by minimizing the amount we checksum.  
Right now it wil read and sum the entire of files that are of the same size.
Given that the many images from the BMPCC4k will be the same size, it would be 
very slow to read all of it.

Instead, create a recursive function that takes a set of files and creates new 
sets of files with matching checksums.  

Iterate through a set of files (initialy matched on size) and break that group
into smaller groups with the same checksum (via dictionary).  Call again with 
each group of two or more files.

