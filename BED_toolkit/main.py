import sys
from Class.bed_class import *


# The input
user_input = sys.argv[1]

bed_data = Read_file(user_input)
data_loaded = bed_data.load_data()
bed_data = Sequence(data_loaded)
print(bed_data.validation)

# print(bed_data.test())

