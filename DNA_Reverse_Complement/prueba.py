import sys
from clases.sequence import Sequence
from clases.read_file import Read_file
from fastapi import FastAPI
from fastapi.responses import FileResponse
 
app = FastAPI()
 
@app.get("/DNA_toolkit")
def API(input: str):                        # pass the sequence in, this time as a query param
    DNA = Sequence(input)
    
    res = {"Length": str(DNA.length()),         # for the txt file
            "Reverse": DNA.reverse(),
            "complement":DNA.complement(),
            "Reverse and complement": DNA.reverse_and_complement(),
            "gc_percentage": str(DNA.gc_percentage())
            } 
    with open('/Users/monkiky/Desktop/Genomics_tools/DNA_Reverse_Complement/result.txt', 'w+') as resFile:
         for i in res:
            resFile.write(i+" "+res[i]+"\n")
    resFile.close()


    return {"Length": DNA.length(),         # For the API call
            "Reverse": DNA.reverse(),
            "complement":DNA.complement(),
            "Reverse and complement": DNA.reverse_and_complement(),
            "gc_percentage": DNA.gc_percentage()
            } 


#         for i in res:
#             resFile.write(i+" "+res[i]+"\n")
#         resFile.close()
# import sys
# from clases.sequence import Sequence
# from clases.read_file import Read_file
# from fastapi import FastAPI

# app = FastAPI()
# @app.get("/DNA_toolkit")
# def sum(input: str):                        # pass the sequence in, this time as a query param
#     DNA = Sequence(input)                    # get the result (i.e., 4)
#     res = {"Length": DNA.length(),         # return the response
#         "Reverse": DNA.reverse(),
#         "complement":DNA.complement(),
#         "Reverse and complement": DNA.reverse_and_complement(),
#         "gc_percentage": DNA.gc_percentage()
#         }



#     with open('result.txt') as resFile:
#         for i in res:
#             resFile.write(i+" "+res[i]+"\n")
#         resFile.close()

#     return {"Length": DNA.length(),         # return the response
#         "Reverse": DNA.reverse(),
#         "complement":DNA.complement(),
#         "Reverse and complement": DNA.reverse_and_complement(),
#         "gc_percentage": DNA.gc_percentage()
#         }