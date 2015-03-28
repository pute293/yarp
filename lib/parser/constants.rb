# coding: utf-8

# define regular expressions for scanner
module YARP::Parser
  
  # special chars
  PDF_WHITE_SPACE = "\x00\x09\x0A\x0C\x0D\x20"
  PDF_DELIMITER   = Regexp.quote('()<>[]{}/%')
  PDF_WORD_BREAK  = PDF_WHITE_SPACE + PDF_DELIMITER
  PDF_WB          = "(?:(?=[#{PDF_WORD_BREAK}])|$)"  # lookahead matching for word-breaking or EOF
  #PDF_WB          = "(?=[#{PDF_WORD_BREAK}])"  # lookahead matching for word-breaking; not macth EOF
  
  def self.regex(str)
    /\A#{str}#{PDF_WB}/n
  end
  #private_class_method :regex
  
  RE_PDF_BEGIN    = /\A%PDF-(\d\.\d)/n
  RE_PDF_END      = /startxref\s*(\d+)\s*%%EOF[#{PDF_WHITE_SPACE}]*/n
  
  # white-space
  RE_PDF_WS       = /\A[#{PDF_WHITE_SPACE}]+/n
  # comment (%...)
  RE_PDF_COMMENT  = /\A%[^\r\n]*/n
  
  # literal true, false, null
  RE_PDF_TRUE     = regex 'true'
  RE_PDF_FALSE    = regex 'false'
  RE_PDF_NULL     = regex 'null'
  
  # num gen obj ... endobj
  # the spec does not mention about gen-obj separator.                       talking about here
  # however, at least Adobe Reader needs white space between them.            v ('+', but not '*')
  RE_PDF_OBJ1     = regex /(\d+)[#{PDF_WHITE_SPACE}]+(\d+)[#{PDF_WHITE_SPACE}]+obj/
  RE_PDF_OBJ2     = regex 'endobj'
  
  # num gen R
  RE_PDF_REF      = regex /(\d+)[#{PDF_WHITE_SPACE}]+(\d+)[#{PDF_WHITE_SPACE}]+R/
  
  # /Name (empty name is legal)
  RE_PDF_NAME     = regex /\/(?:[^#{PDF_WORD_BREAK}#]|#[[:xdigit:]][[:xdigit:]])*/
  
  # numeric
  RE_PDF_INT      = regex /[-+]?\d+/
  RE_PDF_REAL1    = regex /[-+]?\.\d+/      # .1...
  RE_PDF_REAL2    = regex /[-+]?\d+\.\d*/   # 10.1...
  
  # (string)
  RE_PDF_SL       = /\A(?<p>\((?:[^()\\]|\\[\x00-\xff]|\g<p>)*\))/n
  
  # <xxstringxx>
  RE_PDF_SH       = /\A<[[:xdigit:]#{PDF_WHITE_SPACE}]+>/n
  
  # array [ ... ]
  RE_PDF_A1       = /\A\[/n
  RE_PDF_A2       = /\A\]/n
  
  # dictionary << ... >>
  RE_PDF_D1       = /\A<</n
  RE_PDF_D2       = /\A>>/n
  
  # stream ... endstream
  RE_PDF_STREAM1  = /\Astream[\r ]?\n/n
  RE_PDF_STREAM2  = regex 'endstream'
  
  # xref table
  RE_PDF_XREF     = /\Axref[#{PDF_WHITE_SPACE}]+/n
  RE_PDF_XREF_SUB1= /\A(\d+) (\d+)[#{PDF_WHITE_SPACE}]+/n
  RE_PDF_XREF_SUB2= /\A(\d{10}) (\d{5}) ([fn])[ \r][\r\n]/n
  RE_PDF_TRAILER  = regex 'trailer'
  
  # PostScript
  ## numeric
  RE_PS_INT      = regex /(\d+)#([\dA-Za-z]+)/
  RE_PS_REAL1    = regex /[-+]?\.\d+[Ee]\d+/
  RE_PS_REAL2    = regex /[-+]?\d+\.\d*[Ee]\d+/   # 10.1...
  ## //xxx immediately evaluated name
  RE_PS_IEN       = regex /\/\/(?:[^#{PDF_WORD_BREAK}#]|#[[:xdigit:]][[:xdigit:]])+/
  ## procedure defenition
  RE_PS_P1        = /\A\{/n
  RE_PS_P2        = /\A\}/n
  
  
  class << self
    undef regex
  end
end

