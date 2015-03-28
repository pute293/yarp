class YARP::Parser::PostScriptParser
token
  # keyword
  PS_TRUE PS_FALSE PS_NULL # true false null
  # delimiters
  PS_STRL_L  PS_STRL_R      # ( )
  PS_STRH_L  PS_STRH_R      # < >
  PS_ARRAY_L PS_DICT_L      # [, << => MARK
  PS_PROC_START PS_PROC_END # { }
  # others
  PS_NAME                   # /...
  PS_IEN                    # //...
  PS_NUM_INT                # interger
  PS_NUM_REAL               # real number
  PS_STR_ASCII
  PS_STR_HEX
  PS_OP
  PS_MARK

rule
  ps_values         : ps_value
                    | ps_values ps_value
  ps_value          : PS_TRUE             { op_push(val[0]) }
                    | PS_FALSE            { op_push(val[0]) }
                    | PS_NULL             { op_push(val[0]) }
                    | PS_NAME             { op_push(val[0]) }
                    | PS_IEN              { op_push(on_iename(val[0])) }
                    | PS_NUM_INT          { op_push(val[0]) }
                    | PS_NUM_REAL         { op_push(val[0]) }
                    | PS_OP               { on_operation(val[0]) }
                    | PS_MARK             { op_push(MARK) }
                    | ps_str              { op_push(val[0]) }
                    | ps_proc             { op_push(val[0]) }
  ps_str            : PS_STRL_L PS_STRL_R                 { retult = PsString.new('') }     # () empty string
                    | PS_STRH_L PS_STRH_R                 { retult = PsString.new('') }     # <> empty string
                    | PS_STRL_L PS_STR_ASCII PS_STRL_R    { result = PsString.new(val[1]) } # (...)
                    | PS_STRH_L PS_STR_HEX PS_STRH_R      { result = PsString.new(val[1]) } # <...>
  ps_proc           : PS_PROC_START { enter_proc } ps_proc_ops PS_PROC_END { result = exit_proc }
  ps_proc_ops       :
                    | ps_values
  
  
end
