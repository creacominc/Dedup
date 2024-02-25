# Dedup
dedup swift project

2024-02-25

Adding unit test functionality from container.


2023-10-29

Next step:  There is now a mapping of folders which contain duplicates and the 
number of duplicates they contain.  We need a modal dialog to manage the duplicates.  
The workflow will be as follows:  Having chosen folders; found files of the same sizes; 
and found the duplicates by md5 checksums; starting with the folders with the largest 
space used in duplicate files, show the location of the two files.

NOTE:  Need to add a test for symbolic or hard links and verify that we do not follow 
them.  It may be useful to replace the duplicates with symlinks or hard links rather 
than removing them.



2023-10-01

Done:  Increase efficiency by minimizing the amount we checksum.  
Right now it wil read and sum the entire of files that are of the same size.
Given that the many images from the BMPCC4k will be the same size, it would be 
very slow to read all of it.

Instead, create a recursive function that takes a set of files and creates new 
sets of files with matching checksums.  

Iterate through a set of files (initialy matched on size) and break that group
into smaller groups with the same checksum (via dictionary).  Call again with 
each group of two or more files.

