%{
  #include <stdlib.h>
  #include <stdio.h>
  #include <limits.h>
  #include "type_synth.h"
  
  #define MAX_VAR_STRLEN 255

  #include "algo2asm.tab.h"

  void string_to_int(int *v, const char *s);
%}
%option noyywrap
%%
\\begin\{algo\}         { printf("BEGIN"); return BG; } 
\\end\{algo\}           { printf("END"); return END; }
\\SET                   { printf("SET"); return SET; }
\\RETURN                { printf("RETURN"); return RETURN; }
\\IF                    { printf("IF"); return IF; }
\\FI                    { printf("FI"); return FI; }
\\ELSE                  { printf("ELSE"); return ELSE; }
\\DOWHILE               { printf("DOWHILE"); return DOWHILE; }
\\OD                    { printf("OD"); return OD; }
"<"                     { printf("<"); return LOWER; }
"<="                    { printf("<="); return LOWEREQ; }
"="                     { printf("="); return EQ; }
"!="                    { printf("!="); return NEQ; }
">"                     { printf(">"); return GREATER; }
">="                    { printf(">+"); return GREATEREQ; }
[a-zA-Z_]+[a-zA-Z0-9_]* { printf("VAR:%s", yytext); strncpy(yylval.var_name, yytext, MAX_VAR_STRLEN); return VARNAME; }
[+|-]?[[:digit:]]+            { string_to_int(&yylval.integer, yytext); printf("NUMBER:%d", yylval.integer); return NUMBER; }
[[:blank:]]
\n                      { printf("\n"); }
.		                    { printf("%c", yytext[0]); return yytext[0]; }     
%%

void string_to_int(int *r, const char *s) {
  char *p;
  long v;
  errno = 0;
  v = strtol(s, &p, 10);
  if ((*p != '\0' || 
      (errno == ERANGE && (v == LONG_MIN || v == LONG_MAX))) || 
      (v < INT_MIN || v > INT_MAX)) {
    fprintf(stderr, "Error converting string to int\n");
    exit(EXIT_FAILURE);
  } 
  *r = v;
}