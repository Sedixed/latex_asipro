%{
  #include <stdlib.h>
  #include <stdio.h>
  #include <sys/types.h>
  #include <sys/stat.h>
  #include <fcntl.h>
  #include <unistd.h>
  #include "type_synth.h"

  #define MAX_VAR_STRLEN 255
  #define FILE_PATH "output.asm"

  int yylex(void);
  void yyerror(char const *);

  /**
   * Opens the file get from the path FILE_PATH and associates it
   * to the file descriptor fd.
   * Returns -1 in case of failure, 0 otherwise.
   *
   */
  int open_file();

  /**
   * Closes the file get from the path FILE_PATH.
   * Returns -1 in case of failure, 0 otherwise.
   *
   */
  int close_file();

  // file descriptor for output asm file
  int fd;
%}
%union {
  type_synth s;
  int integer;
  char var_name[MAX_VAR_STRLEN + 1];
}

%type<s> expr
%token<integer> NUMBER
%token<var_name> VARNAME 
%token BG END SET RETURN IF FI ELSE DOWHILE OD
%start algo
%%
algo:
  error           { yyerrok; }
| error algo      { yyerrok; }
| BG '{' VARNAME '}' '{' lparam '}' block_instr END { printf("fin d'analyse\n"); }
;

block_instr:
  instr
| instr block_instr
;

lparam:
  VARNAME
| VARNAME ',' lparam
;

instr:
  SET '{' VARNAME '}' '{' expr '}' {
    //fprintf(stdout, "AFFECT:%s\n", $3);
  }

  RETURN '{' expr '}' {
    fprintf(stdout, "el return\n");
  }


//| instr
;

expr:
  VARNAME {
    printf("_V%s_\n", $1);
    $$ = NUMERIC;
  }

| NUMBER {
    //printf("_N%d_\n", $1);
    $$ = NUMERIC;
  }
; 
%%

void yyerror(char const *s) {
  fprintf(stderr, "%s\n", s);
}

int main(void) {
  open_file();

  yyparse();

  close_file();
  return EXIT_SUCCESS;
}

int open_file() {
  fd = open(FILE_PATH, O_CREAT |  O_RDWR | O_APPEND | O_TRUNC, S_IRUSR | S_IWUSR);
	if (fd < 0) {
		perror("open ");
		return -1;
	}
  return 0;
}

int close_file() {
  if (close(fd) < 0) {
    perror("close ");
    return -1;
  }
  return 0;
}