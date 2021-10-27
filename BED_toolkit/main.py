import sys
from Class.bed_class import Bed_tools
from Class.read_bed_file import Read_file


# Take the input file
user_input = sys.argv[1]

# Take
bed_data = Read_file(user_input)
data_loaded = bed_data.load_data()
print(data_loaded)

bed_data = Bed_tools(data_loaded)

user_input2 = sys.argv[2]
chro = user_input2.split(":")[0]
position = user_input2.split(":")[1]


# print(chro)
# print(position)
print(bed_data.targe_region( data_loaded, chro, position))

