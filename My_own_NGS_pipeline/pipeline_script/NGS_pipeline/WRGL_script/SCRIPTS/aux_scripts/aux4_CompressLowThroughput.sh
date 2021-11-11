# Compress the analysis folders ready for archiving
# NOTE: Currently does not require qsub for use
#

# load variables
. *.variables
. *.config

# Compress individual samples
while read d; do
        tar -czvf "$d".tar.gz "$d"
        md5sum "$d".tar.gz > "$d".tar.gz.md5
        rm -rf "$d"
done < IDs.txt

# move run level files into folder and compress
mkdir "$RunID"_Files
mv *.sh *.sh.e* *.sh.o* *.vcf *.idx *.table *.list *.csv *.config *.txt *.bed complete started "$RunID"_Files
tar -czvf "$RunID"_Files.tar.gz "$RunID"_Files
md5sum "$RunID"_Files.tar.gz > "$RunID"_Files.tar.gz.md5
rm -rf "$RunID"_Files
