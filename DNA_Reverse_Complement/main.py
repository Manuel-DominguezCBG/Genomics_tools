import sys
from clases.sequence import Sequence
from clases.read_file import Read_file

# The input:
user_input = sys.argv[1]

# To be able to get two type of input
# A sequence from the command line 
    # python main.py TATA
# A file.txt with the sequence
    # python main.py PATH/file_name.txt

if 'txt' in user_input:
    DNA = Read_file(user_input)
    data_loaded = DNA.load_data()
    DNA = Sequence(data_loaded)
else:
    DNA = Sequence(user_input)

# print(DNA.load_data())
print("Length:")
print(DNA.length())
print("\n")

print("Reverse:")
print(DNA.reverse())
print("\n")

print("Complement:")
print( DNA.complement())
print("\n")

print("Reverse complement")
print(DNA.reverse_and_complement())
print("\n")

print("GC proportion")
print(DNA.gc_percentage())