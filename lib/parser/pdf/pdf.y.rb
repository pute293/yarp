# coding: utf-8

class PDF::Parser::ObjectParser
token
  # keyword
  PDF_TRUE PDF_FALSE PDF_NULL # true false null
  # delimiters
  PDF_STRL_L  PDF_STRL_R      # ( )
  PDF_STRH_L  PDF_STRH_R      # < >
  PDF_ARRAY_L PDF_ARRAY_R     # [ ]
  PDF_DICT_L  PDF_DICT_R      # << >>
  PDF_STREAM  PDF_STREAM_END  # stream endstream
  PDF_OBJ     PDF_OBJ_END     # n m obj, endobj
  PDF_REF                     # n m R
  # trailer
  PDF_XREF_TABLE              # xref ...
  PDF_TRAILER                 # trailer
  # others
  PDF_NAME                    # /...
  PDF_NUM_INT                 # interger
  PDF_NUM_REAL                # real number
  PDF_STR_ASCII
  PDF_STR_HEX
  STREAM_BYTES

rule
  pdf_value         : PDF_TRUE
                    | PDF_FALSE
                    | PDF_NULL
                    | PDF_NAME
                    | PDF_NUM_INT
                    | PDF_NUM_REAL
                    | pdf_str
                    | pdf_array
                    | pdf_dict
                    | pdf_stream
                    | pdf_obj
                    | pdf_ref
                    | pdf_trailer # ...
  pdf_str           : PDF_STRL_L PDF_STRL_R               { retult = '' }     # () empty string
                    | PDF_STRH_L PDF_STRH_R               { retult = '' }     # <> empty string
                    | PDF_STRL_L PDF_STR_ASCII PDF_STRL_R { result = val[1] } # (...)
                    | PDF_STRH_L PDF_STR_HEX PDF_STRH_R   { result = val[1] } # <...>
  pdf_array         : PDF_ARRAY_L PDF_ARRAY_R             { result = [] }     # [] empty array
                    | PDF_ARRAY_L pdf_array_content PDF_ARRAY_R               # [...]
                                                          { result = val[1] }
  pdf_array_content : pdf_value                           { result = [val[0]] }
                    | pdf_array_content pdf_value         { result << val[1] }
  pdf_dict          : PDF_DICT_L PDF_DICT_R                                   # << >> empty dictionary
                                                          { result = {}; @last_dict = result }
                    | PDF_DICT_L pdf_dict_pairs PDF_DICT_R                    # << ... >>
                                                          { result = val[1]; @last_dict = result }
  pdf_dict_pairs    : PDF_NAME pdf_value                  { result = { val[0] => val[1] } } # /NAME ...
                    | pdf_dict_pairs PDF_NAME pdf_value   { result[val[1]] = val[2] }
  pdf_stream        : pdf_dict PDF_STREAM STREAM_BYTES PDF_STREAM_END
                                                          { val[0][:_stream_] = val[2] }  # stream ... endstream
  pdf_obj           : PDF_OBJ pdf_value PDF_OBJ_END                           # num gen obj ... endobj
                                                          { result = PdfObject.create(self, val[0][0], val[0][1], val[1]) }
  pdf_ref           : PDF_REF                             { result = Ref.new(self, val[0][0], val[0][1]) } # num gen R
                                                          
  pdf_trailer       : PDF_XREF_TABLE PDF_TRAILER pdf_dict                     # xref ... trailer << ... >>
                                                          #{ result = { :xref => val[0], :trailer => val[2] }; accept() }
                                                          { result = XRef.new(self, val[0], val[2]); @accepted = true }
  
end
