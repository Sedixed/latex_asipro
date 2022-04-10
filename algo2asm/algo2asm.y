%{
  #define _POSIX_C_SOURCE 200809L
  #include <stdlib.h>
  #include <stdio.h>
  #include <sys/types.h>
  #include <sys/stat.h>
  #include <fcntl.h>
  #include <unistd.h>
  #include <stdarg.h>
  #include <limits.h>
  #include "stable.h"
  #include "type_synth.h"

  #define MAX_VAR_STRLEN 255
  #define FILE_PATH "output.asm"

  int yylex(void);
  void yyerror(char const *);
  void free_symbol_table();
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
   * Prints in the file described by fd the required
   * beginning of the output file.
   *
   */
  void print_start_of_file();

  /**
   * Prints in the file described by fd the required
   * ending of the output file.
   *
   */
  void print_end_of_file();

  // File descriptor for output asm file
  int fd;
%}
%union {
  type_synth s;
  int integer;
  char var_name[MAX_VAR_STRLEN + 1];
}

%type<s> expr instr
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
    if ($6 != NUMERIC) {
      fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
    } else {

      if (search_symbol_table($3) != NULL) {
        // rien je pense car c'est legit en latex jcrois
      }

      symbol_table_entry *ste = new_symbol_table_entry($3);
      // pas sûr du global
			ste->class = GLOBAL_VARIABLE;
			ste->desc[0] = INT_T;
			dprintf(fd,
        "; Affect a value to the variable %s\n"
        "\tconst ax,var:%s\n"
        "\tpop bx\n"
        "\tstorew bx,ax\n", $3, $3);
			$$ = STATEMENT;
    }
  }

| RETURN '{' expr '}' {
    //fprintf(stdout, "el return\n");
  }

//| instr
;


// --- expr ---

expr:
  VARNAME {
    symbol_table_entry *var = search_symbol_table($1);
		if (var == NULL) {
			fprintf(stderr, "** ERREUR ** : La variable %s n'existe pas\n", $1);
			$$ = UNDEFINED_VARIABLE;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      dprintf(fd,
        "; Reading the variable named %s\n"
        "\tconst ax,var:%s\n"
        "\tloadw bx,ax\n"
        "\tpush bx\n", $1, $1);
			$$ = NUMERIC;
		}
  }

| NUMBER {
    dprintf(fd,
      "; Reading the number %d\n"
      "\tconst ax,%d\n"
      "\tpush ax\n", $1, $1);
    $$ = NUMERIC;
  }

| expr '+' expr {
    if ($1 != NUMERIC || $3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      dprintf(fd,
        "; Adding two expressions\n"
        "\tpop ax\n"
        "\tpop bx\n"
        "\tadd ax,bx\n"
        "\tpush ax\n");
			$$ = NUMERIC;
		}
  }

| expr '-' expr {
    if ($1 != NUMERIC || $3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      dprintf(fd,
        "; Substracting two expressions\n"
        "\tpop ax\n"
        "\tpop bx\n"
        "\tsub bx,ax\n"
        "\tpush bx\n");
			$$ = NUMERIC;
		}
  }

  | expr '*' expr {
		if ($1 != NUMERIC || $3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      dprintf(fd,
        "; Multiplying two expressions\n"
        "\tpop ax\n"
        "\tpop bx\n"
        "\tmul ax,bx\n"
        "\tpush ax\n");
			$$ = NUMERIC;
		}
	}

	| expr '/' expr {
		if ($1 != NUMERIC || $3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      dprintf(fd,
        "; Dividing two expressions\n"
        "\tconst cx,div_err\n"
        "\tpop ax\n"
        "\tpop bx\n"
        "\tdiv bx,ax\n"
        "\tjmpe cx\n"
        "\tpush ax\n");
			$$ = NUMERIC;
		}
	}

| '-' expr %prec UMINUS {
    if ($2 != NUMERIC) {
      fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
    } else {
      dprintf(fd,
        "; Multiplying an expression by -1 (unary minus)\n"
        "\tpop ax\n"
        "\tconst bx,-1\n"
        "\tmul ax,bx\n"
        "\tpush ax\n");
			$$ = NUMERIC;	
		}
  }
; 
%%

// --- Functions implantations ---

void yyerror(char const *s) {
  fprintf(stderr, "%s\n", s);
}

int main(void) {
  open_file();

  print_start_of_file();

  yyparse();

  print_end_of_file();

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

void print_start_of_file() {
  dprintf(fd,
    "; ASM file obtained from a LaTeX file\n\n"
    "\tconst ax,beginning\n"
    "jmp ax\n\n"
    ":div_err_str\n"
    "@string \"Erreur : Division par 0 impossible\\n\"\n\n"
    ":div_err\n"
    "\tconst ax,div_err_str\n"
    "\tcallprintfs ax\n"
    "\tend\n\n"
    ":beginning\n"
    "; Stack preparation\n"
    "\tconst bp,stack\n"
    "\tconst sp,stack\n"
    "\tconst ax,2\n"
    "\tsub sp,ax\n");
}

void print_end_of_file() {
  dprintf(fd, 
    "\tend\n\n"
    "; Variable declarations\n");

  // Variable declarations
	symbol_table_entry *st = symbol_table_get_head();
	while (st != NULL) {
		dprintf(fd, "\n:var:%s\n", st->name);
		dprintf(fd, "@int 0\n");
		st = st->next;
	}
	free_symbol_table();
  
  dprintf(fd,
    "\n;Stack zone\n"
    ":stack\n"
    "@int 0\n");
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

void free_symbol_table() {
	while (symbol_table_get_head() != NULL) {
		free_first_symbol_table_entry();
	}
}