%{
  #include <stdlib.h>
  #include <stdio.h>
  #include "type_synth.h"

  #define MAX_VAR_STRLEN 255

  int yylex(void);
  void yyerror(char const *);
%}
%union{
  type_synth s;
  int integer;
  char var_name[MAX_VAR_STRLEN + 1];
}
%type<s> expr
%token<integer> NUMBER
%token<var_name> VARNAME 
%token BG END SET
%start algo
%%
algo:
  error           { yyerrok; }
| error algo      { yyerrok; }
| BG '{' VARNAME '}' '{' lparam '}' instr END
| 
;

lparam:
  VARNAME
| VARNAME ',' lparam
;

instr:
  SET '{' VARNAME '}' '{' expr '}' {
    fprintf(stderr, "Nom: %s\n", $3);
  }
| instr instr
;

expr:
  VARNAME {
    $$ = NUMERIC;
  }
| NUMBER {
  printf("%d\n", $1);
  $$ = NUMERIC;
}
; 
%%

void yyerror(char const *s) {
  fprintf(stderr, "%s\n", s);
}