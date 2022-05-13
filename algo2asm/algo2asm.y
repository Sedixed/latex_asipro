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
  #include <assert.h>
  #include "stable.h"
  #include "type_synth.h"

  #define MAX_VAR_STRLEN 255
  #define FILE_PATH "output.asm"
  #define MAXBUF 255

  // Stack
  #define STACK_SIZE 1024
  unsigned int stack[STACK_SIZE];
  size_t stack_index = 0;
  void push(unsigned int e);
  unsigned int pop();
  unsigned int top();

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

%left LOWER LOWEREQ GREATER GREATEREQ
%left EQ NEQ
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

  | IF '{' expr '}' if block_instr esle fi end_b FI {
		if ($3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		}		
	}

	| IF '{' expr '}' if block_instr ELSE esle block_instr fi end_b FI {
		if ($3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		}		
	}

  | DOWHILE begin_while '{' expr '}' while block_instr elihw end_b OD {
		if ($4 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		}
	}
;


if : {
	unsigned int n = new_label_number();
  push(n);
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "else_%u", n);
  dprintf(fd,
    "; Begin of the \"if\" condition (%u)\n"
    "\tpop ax\n"
    "\tconst bx,0\n"
    "\tconst cx,%s\n"
    "\tcmp ax,bx\n"
    "\tjmpc cx\n"
    "; True case of the \"if\" condition  (%u)\n", n, buf, n);
}

esle : {
	unsigned int n = top();
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "else_%u", n);
  dprintf(fd,
    "\tconst ax,end_if_%u\n"
    "\tjmp ax\n"
    ":%s\n"
    "; False case of the \"if\" condition (%u)\n", n, buf, n
  );
}

fi : {
	unsigned int n = top();
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "end_if_%u", n);
	dprintf(fd, ":%s\n", buf);
}

begin_while : {
	unsigned int n = new_label_number();
	push(n);
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "while_%u", n);
  dprintf(fd,
    "; Beginning of the \"do while\" loop  (%u)\n"
    ":%s\n", n, buf
  );
}

while : {
	unsigned int n = top();
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "end_while_%u", n);
  dprintf(fd,
    "\tpop ax\n"
    "\tconst bx,0\n"
    "\tconst cx,%s\n"
    "\tcmp ax,bx\n"
    "\tjmpc cx\n", buf
  );
}

elihw : {
	unsigned int n = top();
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "end_while_%u", n);
  dprintf(fd,
    "\tconst ax,while_%u\n"
    "\tjmp ax\n"
    ":%s\n", n, buf
  );
}

end_b : {
	unsigned int n = pop();
  dprintf(fd, "; End of the loop/condition (%u)\n", n);
}


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

| expr LOWER expr {
  if ($1 != NUMERIC || $3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      unsigned int n = new_label_number();
			char buf[MAXBUF];
			create_label(buf, MAXBUF, "lower_than_%u", n);
			char buf2[MAXBUF];
			create_label(buf2, MAXBUF, "end_lower_than_%u", n);
			// Début de la comparaison
      dprintf(fd,
        "; Comparison number %u of type \"lower than\"\n"
        "\tpop ax\n"
        "\tpop bx\n"
        "\tconst cx,%s\n"
        "\tsless bx,ax\n"
        "\tjmpc cx\n"
        "; False case\n"
        "\tconst ax,0\n"
        "\tpush ax\n"
        "\tconst ax,%s\n"
        "\tjmp ax\n"
        "; True case\n"
        ":%s\n"
        "\tconst ax,1\n"
        "\tpush ax\n"
        "; End of comparison number %u of type \"lower than\"\n"
        ":%s\n", n, buf, buf2, buf, n, buf2
      );
      $$ = NUMERIC;
		}
}

| expr LOWEREQ expr {
  if ($1 != NUMERIC || $3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      int n = new_label_number();
			char buf[MAXBUF];
			create_label(buf, MAXBUF, "lowereq_%u", n);
			char buf2[MAXBUF];
			create_label(buf2, MAXBUF, "end_lowereq_%u", n);
      dprintf(fd,
        "; Comparison number %u of type \"lowereq\"\n"
        "\tpop ax\n"
        "\tpop bx\n"
        "\tcp cx,bx\n"
        "\tconst dx,%s\n"
        "\tsless bx,ax\n"
        "\tjmpc dx\n"
        "\tcmp cx,ax\n"
        "\tjmpc dx\n"
        "; False case\n"
        "\tconst ax,0\n"
        "\tpush ax\n"
        "\tconst ax,%s\n"
        "\tjmp ax\n"
        "; True case\n"
        ":%s\n"
        "\tconst ax,1\n"
        "\tpush ax\n"
        "; End of comparison number %u of type \"lowereq\"\n"
        ":%s\n",n, buf, buf2, buf, n, buf2
      );
			$$ = NUMERIC;
		}
}

| expr EQ expr {
  if ($1 != NUMERIC || $3 != NUMERIC) {
    fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
		$$ = TYPE_ERR;
		free_symbol_table();
		exit(EXIT_FAILURE);
  } else {
    unsigned int n = new_label_number();
    char buf1[MAXBUF];
		create_label(buf1, MAXBUF, "equals_%u", n);
		char buf2[MAXBUF];
		create_label(buf2, MAXBUF, "end_equals_%u", n);
    dprintf(fd,
      "; Comparison number %u of type \"equals\"\n"
      "\tpop ax\n"
      "\tpop bx\n"
      "\tconst cx,%s\n"
      "\tcmp ax,bx\n"
      "\tjmpc cx\n"
      "; False case\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case\n"
      ":%s\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "; End of comparison number %u of type \"equals\"\n"
      ":%s\n", n, buf1, buf2, buf1, n, buf2
    );
    $$ = NUMERIC;
  }
}

| expr NEQ expr {
  if ($1 != NUMERIC || $3 != NUMERIC) {
    fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
		$$ = TYPE_ERR;
		free_symbol_table();
		exit(EXIT_FAILURE);
  } else {
    unsigned int n = new_label_number();
    char buf1[MAXBUF];
		create_label(buf1, MAXBUF, "nequals_%u", n);
		char buf2[MAXBUF];
		create_label(buf2, MAXBUF, "end_nequals_%u", n);
    dprintf(fd,
      "; Comparison number %u of type \"nequals\"\n"
      "\tpop ax\n"
      "\tpop bx\n"
      "\tconst cx,%s\n"
      "\tcmp ax,bx\n"
      "\tjmpc cx\n"
      "; True case\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; False case\n"
      ":%s\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "; End of comparison number %u of type \"nequals\"\n"
      ":%s\n", n, buf1, buf2, buf1, n, buf2
    );
    $$ = NUMERIC;
  }
}

| expr GREATER expr {

}

| expr GREATEREQ expr {

}

| '(' expr ')' {
    $$ = $2;
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
  fd = open(FILE_PATH, O_CREAT | O_RDWR | O_APPEND | O_TRUNC, S_IRUSR | S_IWUSR);
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
    "\tjmp ax\n\n"
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
	if (current_label_number == UINT_MAX) {
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

void push(unsigned int e) {
  assert(stack_index < STACK_SIZE);
	stack[stack_index++] = e;
}

unsigned int pop() {
  assert(stack_index > 0);
	return stack[--stack_index];
}

unsigned int top() {
  assert(stack_index > 0);
	return stack[stack_index - 1];
}