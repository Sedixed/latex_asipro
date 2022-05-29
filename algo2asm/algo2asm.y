%{
  #define _POSIX_C_SOURCE 200809L
  #include <stdlib.h>
  #include <stdio.h>
  #include <string.h>
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

  int arguments_to_free = 0;

  /**
   * Opens the file get from the path FILE_PATH and associates it
   * to the file descriptor fd.
   * Returns -1 in case of failure, 0 otherwise.
   *
   */
  int open_file();

  /**
   * Get the variable named name in the asipro stack and push it on the top 
   * of the stack.
   */
  void get_asm_var(const char *name);

  /**
   * Update the variable named name in the asipro stack with the value on the 
  *  top of the stack.
   */
  void update_asm_var(const char *name);

  /**
   * Push or pop var in asipro and update the symbol table.
   */
  void push_var(const char *registry);
  void pop_var(const char *registry);

  /**
   * Closes the file get from the path FILE_PATH.
   * Returns -1 in case of failure, 0 otherwise.
   *
   */
  int close_file();

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

%left OR
%left AND
%left LOWER LOWEREQ GREATER GREATEREQ
%left EQ NEQ
%left '+' '-' 
%left '*' '/'
%left CALL
%right UMINUS
%right NOT

%start algo
%%
algo:
  error           { yyerrok; }
| error algo      { yyerrok; }
| BG '{' VARNAME '}' {
    dprintf(fd,
      "; ASM file obtained from a LaTeX file\n\n"
      "\tconst ax,main\n"
      "\tjmp ax\n\n"
      ":div_err_str\n"
      "@string \"Erreur : Division par 0 impossible\\n\"\n\n"
      ":div_err\n"
      "\tconst ax,div_err_str\n"
      "\tcallprintfs ax\n"
      "\tend\n\n"
      ":%s\n", $3);
  } '{' lparam '}' {
    symbol_table_entry *ste = new_symbol_table_entry("!RET");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
  } block_instr END
;

block_instr:
  instr
| instr block_instr
;

lparam:
  param
| param ',' lparam
;

param:
  VARNAME {
    // Ajoute la variable dans la table des symboles et asipro
    symbol_table_entry *ste = new_symbol_table_entry($1);
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
  }

// --- instr ---

instr:
  SET '{' VARNAME '}' '{' expr '}' {
    if (search_symbol_table($3) != NULL) {
      // Update the variable in the asipro stack
      update_asm_var($3);
    } else {
      // Add the on the asipro stack
      dprintf(fd, "; Add the %s variable in the stack\n", $3);
      pop_var("ax");
      dprintf(fd, "\tpush ax\n");
      // Update the symbol table
      symbol_table_entry *ste = new_symbol_table_entry($3);
      ste->class = GLOBAL_VARIABLE;
      ste->desc[0] = INT_T;
      $$ = STATEMENT;
    }
  }

  | RETURN '{' expr '}' {
    // Stock the value in ax and free the stack
    pop_var("ax");
    symbol_table_entry *st = symbol_table_get_head();
    while (st != NULL) {
      if (strcmp(st->name, "!RET") == 0) {
        break;
      }
      fprintf(stderr, "%s", st->name);
      dprintf(fd, "\tpop dx\n");
      st = st->next;
    }
    dprintf(fd, "\tret\n");
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
  dprintf(fd, "; Begin of the \"if\" condition (ID: %u)\n", n);
  pop_var("ax");
  dprintf(fd,
    "\tconst bx,0\n"
    "\tconst cx,%s\n"
    "\tcmp ax,bx\n"
    "\tjmpc cx\n"
    "; True case of the \"if\" condition (ID: %u)\n", buf, n);
}

esle : {
	unsigned int n = top();
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "else_%u", n);
  dprintf(fd,
    "\tconst ax,end_if_%u\n"
    "\tjmp ax\n"
    ":%s\n"
    "; False case of the \"if\" condition (ID: %u)\n", n, buf, n
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
    "; Beginning of the \"do while\" loop (ID: %u)\n"
    ":%s\n", n, buf
  );
}

while : {
	unsigned int n = top();
	char buf[MAXBUF];
	create_label(buf, MAXBUF, "end_while_%u", n);
  pop_var("ax");
  dprintf(fd,
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
  dprintf(fd, "; End of the loop/condition (ID: %u)\n", n);
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
      get_asm_var($1);
			$$ = NUMERIC;
		}
  }

| NUMBER {
    dprintf(fd,
      "; Reading the number %d\n"
      "\tconst ax,%d\n", $1, $1);
    push_var("ax");
    $$ = NUMERIC;
  }

| expr '+' expr {
    if ($1 != NUMERIC || $3 != NUMERIC) {
			fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
			$$ = TYPE_ERR;
			free_symbol_table();
			exit(EXIT_FAILURE);
		} else {
      dprintf(fd, "; Adding two expressions\n");
      pop_var("ax");
      pop_var("bx");
      dprintf(fd, "\tadd ax,bx\n");
      push_var("ax");
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
      dprintf(fd, "; Substracting two expressions\n");
      pop_var("ax");
      pop_var("bx");
      dprintf(fd, "\tsub bx,ax\n");
      push_var("bx");
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
      dprintf(fd, "; Multiplying two expressions\n");
      pop_var("ax");
      pop_var("bx");
      dprintf(fd, "\tmul ax,bx\n");
      push_var("ax");
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
        "\tconst cx,div_err\n");
      pop_var("ax");
      pop_var("bx");
      dprintf(fd, 
        "\tdiv bx,ax\n"
        "\tjmpe cx\n");
      push_var("bx");
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
      dprintf(fd,"; Multiplying an expression by -1 (unary minus)\n");
      pop_var("ax");
      dprintf(fd,
        "\tconst bx,-1\n"
        "\tmul ax,bx\n");
      push_var("ax");
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
    // Creating labels
    unsigned int n = new_label_number();
    char buf[MAXBUF];
    create_label(buf, MAXBUF, "lower_than_%u", n);
    char buf2[MAXBUF];
    create_label(buf2, MAXBUF, "end_lower_than_%u", n);

    // Comparison
    dprintf(fd, "; Comparison of type \"lower than\" (ID: %u)\n", n);
    pop_var("ax");
    pop_var("bx");
    dprintf(fd,
      "\tconst cx,%s\n"
      "\tsless bx,ax\n"
      "\tjmpc cx\n"
      "; False case (ID: %u)\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case (ID: %u)\n"
      ":%s\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "; End of comparison of type \"lower than\" (ID: %u)\n"
      ":%s\n", buf, n, buf2, n, buf, n, buf2);

    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
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
      
      // Comparison
      dprintf(fd, "; Comparison of type \"lower than or equal\" (ID: %u)\n", n);
      pop_var("ax");
      pop_var("bx");
      dprintf(fd,
        "\tcp cx,bx\n"
        "\tconst dx,%s\n"
        "\tsless bx,ax\n"
        "\tjmpc dx\n"
        "\tcmp cx,ax\n"
        "\tjmpc dx\n"
        "; False case (ID: %u)\n"
        "\tconst ax,0\n"
        "\tpush ax\n"
        "\tconst ax,%s\n"
        "\tjmp ax\n"
        "; True case (ID: %u)\n"
        ":%s\n"
        "\tconst ax,1\n"
        "\tpush ax\n"
        "; End of comparison of type \"lower than or equal\" (ID: %u)\n"
        ":%s\n", buf, n, buf2, n, buf, n, buf2
      );

      // Add the temp variable to the symbol table
      symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
      ste->class = GLOBAL_VARIABLE;
      ste->desc[0] = INT_T;
      $$ = NUMERIC;
		}
}

| expr GREATER expr {
  if ($1 != NUMERIC || $3 != NUMERIC) {
    fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
    $$ = TYPE_ERR;
    free_symbol_table();
    exit(EXIT_FAILURE);
  } else {
    int n = new_label_number();
    char buf[MAXBUF];
    create_label(buf, MAXBUF, "greater_%u", n);
    char buf2[MAXBUF];
    create_label(buf2, MAXBUF, "end_greater_%u", n);
    
    // Comparison
    dprintf(fd, "; Comparison of type \"greater than\" (ID: %u)\n", n);
    pop_var("ax");
    pop_var("bx");
    dprintf(fd,
      "\tcp cx,bx\n"
      "\tconst dx,%s\n"
      "\tsless bx,ax\n"
      "\tjmpc dx\n"
      "\tcmp cx,ax\n"
      "\tjmpc dx\n"
      "; False case (ID: %u)\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case (ID: %u)\n"
      ":%s\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "; End of comparison of type \"greater than\" (ID: %u)\n"
      ":%s\n", buf, n, buf2, n, buf, n, buf2
    );

    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
    $$ = NUMERIC;
  }
}

| expr GREATEREQ expr {
if ($1 != NUMERIC || $3 != NUMERIC) {
    fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
    $$ = TYPE_ERR;
    free_symbol_table();
    exit(EXIT_FAILURE);
  } else {
    // Creating labels
    unsigned int n = new_label_number();
    char buf[MAXBUF];
    create_label(buf, MAXBUF, "greatereq_than_%u", n);
    char buf2[MAXBUF];
    create_label(buf2, MAXBUF, "end_greatereq_than_%u", n);

    // Comparison
    dprintf(fd, "; Comparison of type \"greater than or equal\" (ID: %u)\n", n);
    pop_var("ax");
    pop_var("bx");
    dprintf(fd,
      "\tconst cx,%s\n"
      "\tsless bx,ax\n"
      "\tjmpc cx\n"
      "; False case (ID: %u)\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case (ID: %u)\n"
      ":%s\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "; End of comparison of type \"greater than or equal\" (ID: %u)\n"
      ":%s\n", buf, n, buf2, n, buf, n, buf2);

    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
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

    // Comparison
    dprintf(fd, "; Comparison number of type \"equals\" (ID: %u)\n", n);
    pop_var("ax");
    pop_var("bx");
    dprintf(fd,
      "\tconst cx,%s\n"
      "\tcmp ax,bx\n"
      "\tjmpc cx\n"
      "; False case (ID: %u)\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case (ID: %u)\n"
      ":%s\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "; End of comparison number of type \"equals\" (ID: %u)\n"
      ":%s\n", buf1, n, buf2, n, buf1, n, buf2
    );
    
    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
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

    // Comparison
    dprintf(fd, "; Comparison number of type \"non equals\" (ID: %u)\n", n);
    pop_var("ax");
    pop_var("bx");
    dprintf(fd,
      "\tconst cx,%s\n"
      "\tcmp ax,bx\n"
      "\tjmpc cx\n"
      "; True case (ID: %u)\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; False case (ID : %u)\n"
      ":%s\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "; End of comparison number of type \"non equals\" (ID: %u)\n"
      ":%s\n", buf1, n, buf2, n, buf1, n, buf2
    );
    
    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
    $$ = NUMERIC;
  }
}

| expr OR expr {
  if ($1 != NUMERIC || $3 != NUMERIC) {
    fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
    $$ = TYPE_ERR;
    free_symbol_table();
    exit(EXIT_FAILURE);
  } else {
    int n = new_label_number();
    char buf1[MAXBUF];
    create_label(buf1, MAXBUF, "or_equals_%u", n);
    char buf2[MAXBUF];
    create_label(buf2, MAXBUF, "end_or_equals_%u", n);
    
    // Comparison
    dprintf(fd, "; Logical or (ID: %u)\n", n);
    pop_var("ax");
    pop_var("bx");
    dprintf(fd,
      "\tor ax,bx\n"
      "\tconst bx,0\n"
      "\tconst cx,%s\n"
      "\tcmp ax,bx\n"
      "\tjmpc cx\n"
      "; False case (ID: %u)\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case (ID: %u)\n"
      ":%s\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "; End of comparison number of type \"equals\" (ID: %u)\n"
      ":%s\n", buf1, n, buf2, n, buf1, n, buf2
    );

    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
    $$ = NUMERIC;
  }
}

| expr AND expr {
  if ($1 != NUMERIC || $3 != NUMERIC) {
    fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
    $$ = TYPE_ERR;
    free_symbol_table();
    exit(EXIT_FAILURE);
  } else {
    int n = new_label_number();
    char buf1[MAXBUF];
    create_label(buf1, MAXBUF, "mul_equals_%u", n);
    char buf2[MAXBUF];
    create_label(buf2, MAXBUF, "end_mul_equals_%u", n);
    
    // Comparison
    dprintf(fd, "; Logical or (ID: %u)\n", n);
    pop_var("ax");
    pop_var("bx");
    dprintf(fd,
      "\tmul ax,bx\n"
      "\tconst bx,0\n"
      "\tconst cx,%s\n"
      "\tcmp ax,bx\n"
      "\tjmpc cx\n"
      "; False case (ID: %u)\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case (ID: %u)\n"
      ":%s\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "; End of comparison number of type \"equals\" (ID: %u)\n"
      ":%s\n", buf1, n, buf2, n, buf1, n, buf2
    );

    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
    $$ = NUMERIC;
  }
}

| NOT expr {
  if ($2 != NUMERIC) {
    fprintf(stderr, "** ERREUR ** : Une erreur de type est survenue\n");
		$$ = TYPE_ERR;
		free_symbol_table();
		exit(EXIT_FAILURE);
  } else {
    unsigned int n = new_label_number();
    char buf1[MAXBUF];
		create_label(buf1, MAXBUF, "not_%u", n);
		char buf2[MAXBUF];
		create_label(buf2, MAXBUF, "end_not_%u", n);

    // Comparison
    dprintf(fd, "; Logical not (ID: %u)\n", n);
    pop_var("ax");
    dprintf(fd,
      "\tconst cx,%s\n"
      "\tconst bx,0\n"
      "\tcmp ax,bx\n"
      "\tjmpc cx\n"
      "; False case (ID: %u)\n"
      "\tconst ax,1\n"
      "\tpush ax\n"
      "\tconst ax,%s\n"
      "\tjmp ax\n"
      "; True case (ID: %u)\n"
      ":%s\n"
      "\tconst ax,0\n"
      "\tpush ax\n"
      "; End logical not (ID: %u)\n"
      ":%s\n", buf1, n, buf2, n, buf1, n, buf2
    );
    
    // Add the temp variable to the symbol table
    symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
    ste->class = GLOBAL_VARIABLE;
    ste->desc[0] = INT_T;
    $$ = NUMERIC;
  }
}

| CALL '{' VARNAME '}' '{' lexpr '}' {
  dprintf(fd,
    "; Call the %s function\n"
    "\tconst bx,%s\n"
    "\tcall bx\n", $3, $3);

  // Free the temp variables (parameters) in the symbol table and add the pop
  dprintf(fd, "; Pop the called function args\n");
  for (size_t i = 0; i < arguments_to_free; ++i) {
    pop_var("dx");
  }

  // Push the returned value on the stack
  dprintf(fd, "; Push the returned value on the stack\n");
  push_var("ax");

  $$ = NUMERIC;
}

| '(' expr ')' {
    $$ = $2;
  }
;

lexpr:
  tmp_expr
| tmp_expr ',' lexpr
;

tmp_expr:
  expr {
    ++arguments_to_free;
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

  free_symbol_table();

  close_file();
  return EXIT_SUCCESS;
}

int open_file() {
  fd = open(FILE_PATH, O_CREAT | O_RDWR | O_TRUNC, S_IRUSR | S_IWUSR);
	if (fd < 0) {
		perror("open ");
		return -1;
	}
  return 0;
}

void get_asm_var(const char *name) {
  // Search the index of name
  symbol_table_entry *st = symbol_table_get_head();
  size_t var_index = 0;
	while (st != NULL) {
		if (strcmp(st->name, name) == 0) {
      break;
    }
    ++var_index;
		st = st->next;
	}

  // Add the asm code to calculate the stack adress and push the value
  dprintf(fd,
    "; Get the %s variable and push it in the top of the stack\n"
    "\tconst ax,2\n"
    "\tconst bx,%zu\n"
    "\tmul ax,bx\n"
    "\tcp bx,sp\n"
    "\tsub bx,ax\n"
    "\tloadw ax,bx\n"
    "\tpush ax\n",
    name, var_index
  );

  // Add the pushed variable to the symbol table
  symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
  ste->class = GLOBAL_VARIABLE;
  ste->desc[0] = INT_T;
}

void update_asm_var(const char *name) {
  // Search the index of name
  symbol_table_entry *st = symbol_table_get_head();
  size_t var_index = 0;
	while (st != NULL) {
		if (strcmp(st->name, name) == 0) {
      break;
    }
    ++var_index;
		st = st->next;
	}

  // Add the asm code to calculate the stack adress and update the value
  dprintf(fd,
    "; Update the %s variable in the stack\n"
    "\tconst ax,2\n"
    "\tconst bx,%zu\n"
    "\tmul ax,bx\n"
    "\tcp bx,sp\n"
    "\tsub bx,ax\n"
    "\tpop ax\n"
    "\tstorew ax,bx\n",
    name, var_index
  );

  // Free first table entry
  free_first_symbol_table_entry();
}

void push_var(const char *registry) {
  symbol_table_entry *ste = new_symbol_table_entry("!TEMP");
  ste->class = GLOBAL_VARIABLE;
  ste->desc[0] = INT_T;
  dprintf(fd,
    "; Push a temp variable on the stack\n"
    "\tpush %s\n", registry);
}

void pop_var(const char *registry) {
  free_first_symbol_table_entry();
  dprintf(fd,
    "\tpop %s\n", registry);
}

int close_file() {
  if (close(fd) < 0) {
    perror("close ");
    return -1;
  }
  return 0;
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