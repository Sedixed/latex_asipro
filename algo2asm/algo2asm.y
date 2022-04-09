%{
  #include <stdlib.h>
  #include <stdio.h>
  #include <sys/types.h>
  #include <sys/stat.h>
  #include <fcntl.h>
  #include <unistd.h>
  #include <stdarg.h>
  #include <limits.h>
  #include "type_synth.h"

  #define MAX_VAR_STRLEN 255
  #define FILE_PATH "output.asm"

  int yylex(void);
  void yyerror(char const *);
  static unsigned int current_label_number = 0u;
  static unsigned int new_label_number();
  static void create_label(char *buf, size_t buf_size, const char *format, ...);
	void fail_with(const char *format, ...);

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

  /**
   * Returns 0 if the variable named VARIABLE is defined,
   * -1 otherwise.
   *
   */
  int is_varname_defined(const char *varname);

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

%left '+' '-' 
%left '*' '/'
%right UMINUS

%start algo
%%
algo:
  error           { yyerrok; }
| error algo      { yyerrok; }
| BG '{' VARNAME '}' '{' lparam '}' block_instr END { printf("\nfin d'analyse\n"); }
;

block_instr:
  instr
| instr block_instr
;

lparam:
  VARNAME
| VARNAME ',' lparam
;

// --- instr ---

instr:
  SET '{' VARNAME '}' '{' expr '}' {
    //fprintf(stdout, "AFFECT:%s\n", $3);
  }

| RETURN '{' expr '}' {
    //fprintf(stdout, "el return\n");
  }

//| instr
;


// --- expr ---

expr:
  VARNAME {
    printf("_V%s_\n", $1);
    $$ = NUMERIC;
  }

| NUMBER {
    //printf("_N%d_\n", $1);
    $$ = NUMERIC;
  }

| expr '+' expr {
    // vérifier que si c'est des VARNAME, alors ils sont bien définis
    // implanter fonction is_varname_defined
  }

| expr '-' expr {
    // vérifier que si c'est des VARNAME, alors ils sont bien définis
    // implanter fonction is_varname_defined
  }

| '-' expr %prec UMINUS {
    // vérifier que si c'est des VARNAME, alors ils sont bien définis
    // implanter fonction is_varname_defined
  }
; 
%%

// --- Functions implantations ---

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

int is_varname_defined(const char *varname) {
  //todo
  return 0;
}

static unsigned int new_label_number() {
	if ( current_label_number == UINT_MAX ) {
		fail_with("Error: maximum label number reached!\n");
	}
	return current_label_number++;
}

static void create_label(char *buf, size_t buf_size, const char *format, ...) {
	va_list ap;
	va_start(ap, format);
	if ( vsnprintf(buf, buf_size, format, ap) >= buf_size ) {
		va_end(ap);
		fail_with("Error in label generation: size of label exceeds maximum size!\n");
	}
	va_end(ap);
}

void fail_with(const char *format, ...) {
	va_list ap;
	va_start(ap, format);
	vfprintf(stderr, format, ap);
	va_end(ap);
	exit(EXIT_FAILURE);
}