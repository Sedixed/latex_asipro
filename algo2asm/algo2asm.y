%{
  #include <stdlib.h>
  #include <stdio.h>

  int yylex(void);
  void yyerror(char const *);
%}
%start algo
%token BG END
%%
algo:
  error           { yyerrok; }
| error algo      { yyerrok; }
| BG END
| 
%%

void yyerror(char const *s) {
  fprintf(stderr, "%s\n", s);
}