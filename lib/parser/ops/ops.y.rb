class PDF::Parser::OperationParser
token
  # keyword
  PDF_TRUE PDF_FALSE PDF_NULL # true false null
  # delimiters
  PDF_STRL_L  PDF_STRL_R      # ( )
  PDF_STRH_L  PDF_STRH_R      # < >
  PDF_ARRAY_L PDF_ARRAY_R     # [ ]
  PDF_DICT_L  PDF_DICT_R      # << >>
  # others
  PDF_NAME                    # /...
  PDF_NUM_INT                 # interger
  PDF_NUM_REAL                # real number
  PDF_STR_ASCII
  PDF_STR_HEX
  PDF_OP
  PDF_OP_ID

rule
  pdf_ops           :                                       { result = [] }
                    | pdf_op                                { result = [val[0]] }
                    | pdf_ops pdf_op                        { result << val[1] }
  pdf_op            : PDF_OP                                { result = {:op => val[0][0], :args => nil} }
                    | pdf_values PDF_OP                     {
                                                              size, op, expected_size = val[0].size, *val[1]
                                                              case size <=> expected_size
                                                              when -1 # operands count is too short
                                                                on_error("parse error on Op #{op}; invalid operands count #{size} (#{val[0]}); expected #{expected_size}")
                                                              when 0  # ok
                                                              when 1  # operands count is too long
                                                                # PDF spec says "operands shall not be left over when an operator finishes execution."
                                                                # So excess parameters are ignored here.
                                                                warn "excess #{size - expected_size} parameters (#{val[0][expected_size..-1]}) ignored"
                                                                val[0] = val[0][0,expected_size]
                                                              when nil # variable parameter allowed
                                                              end
                                                              result = {:op => op, :args => val[0]}
                                                            }
                    | pdf_dict PDF_OP_ID                    # inline image (BI ... ID ... EI)
                                                            { result = {:op => :ID, :args => val[0], :data => val[1]} }
  pdf_values        : pdf_value                             { result = [val[0]] }
                    | pdf_values pdf_value                  { result << val[1] }
  pdf_value         : PDF_TRUE
                    | PDF_FALSE
                    | PDF_NULL
                    | PDF_NAME
                    | PDF_NUM_INT
                    | PDF_NUM_REAL
                    | pdf_str
                    | pdf_array
                    | pdf_dict
  pdf_str           : PDF_STRL_L PDF_STRL_R                 { retult = '' }     # () empty string
                    | PDF_STRH_L PDF_STRH_R                 { retult = '' }     # <> empty string
                    | PDF_STRL_L PDF_STR_ASCII PDF_STRL_R   { result = val[1] } # (...)
                    | PDF_STRH_L PDF_STR_HEX PDF_STRH_R     { result = val[1] } # <...>
  pdf_array         : PDF_ARRAY_L PDF_ARRAY_R               { result = [] }     # [] empty array
                    | PDF_ARRAY_L pdf_array_content PDF_ARRAY_R               # [...]
                                                            { result = val[1] }
  pdf_array_content : pdf_value                             { result = [val[0]] }
                    | pdf_array_content pdf_value           { result << val[1] }
  pdf_dict          : PDF_DICT_L PDF_DICT_R                 { result = {} }     # << >> empty dictionary
                    | PDF_DICT_L pdf_dict_pairs PDF_DICT_R  { result = val[1] } # << ... >>
  pdf_dict_pairs    : PDF_NAME pdf_value                    { result = { val[0] => val[1] } } # /NAME ...
                    | pdf_dict_pairs PDF_NAME pdf_value     { result[val[1]] = val[2] }
  
end
