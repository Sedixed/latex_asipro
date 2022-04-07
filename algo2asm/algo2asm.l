%{
  #include <stdlib.h>
  #include <stdio.h>
  #include <limits.h>
  #include "algo2asm.tab.h"

  void string_to_int(int *v, const char *s);
%}
%option noyywrap
%%
\\begin\{algo\} { printf("BEGIN"); return BG; } 
\\end\{algo\}   { printf("END"); return END; }
[[:blank:]]     
.|\n		        { return yytext[0]; }     
%%

void string_to_int(int *r, const char *s) {
  char *p;
  long v;
  errno = 0;
  v = strtol(s, &p, 10);
  if ((*p != '\0' || (errno == ERANGE 
                    && (v == LONG_MIN || v == LONG_MAX))) 
                    || (v < INT_MIN || v > INT_MAX)) {
    fprintf(stderr, "Error converting string to int\n");
    exit(EXIT_FAILURE);
  } 
  *r = v;
}