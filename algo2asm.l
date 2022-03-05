%{
    #include <limits.h>

    typedef enum status {
		NUMERIC,
		//BOOLEAN,
		//ERR_TYPE,
		//ERR_DIV
	} status;

    #include "algo2asm.tab.h"
    void string_to_int(int *v, const char *s);

%}
%option noyywrap
%%

[[:digit:]]+        { string_to_int(&yylval.integer, yytext); return NUMBER; }
\\begin{regex pour un nom de fonction}{regex pour paramètres}
\\end{regex pour nom de fonction}
\\RETURN{une expression donnant un entier ? style 2*i}
\\SET{nomvariable}{valeur entière}
\\...

// j'y pense, peut être pas besoin des {} à chaque fois, ça peut éventuellement
// se gérer avec la règle .|\n ? 



[[:blank:]]
.|\n		        return yytext[0];

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