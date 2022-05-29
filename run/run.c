#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>

#define PATH_MAX 4096

#define ALGORITHMS_FOLDER "../Exemple/"
#define ALGO2ASM_FOLDER "../algo2asm/"

#define MAX_SIPRO_CMD_LENGTH 1024

#define SIPRO_SEPARATOR "{"

#define NAME_MAX 255

#define OUTPUT_SIPRO_NAME "out.sipro"


enum AGRS {
  PROG,
  SIPRO,
  NB_ARGS
};

/**
 * Convert the string pointed by s in an int and store it into the variable 
 * pointed by r.
 */
void string_to_int(int *r, const char *s);

/**
 * Run asipro and sipro commands and print the resul on stdout.
 */
void compile_asm_and_run(const char *asm_path);

int main(int argc, char **argv) {
  // Check args
  if (argc < NB_ARGS) {
    fprintf(stderr, 
        "Error : You need to give the SIPRO command to execute\n");
    return EXIT_FAILURE;
  }

  // Extract the algorithm name
  char sipro_cmd[MAX_SIPRO_CMD_LENGTH + 1];
  memset(sipro_cmd, 0, MAX_SIPRO_CMD_LENGTH + 1);
  strncpy(sipro_cmd, argv[SIPRO], MAX_SIPRO_CMD_LENGTH);
  char *name = strtok(sipro_cmd, SIPRO_SEPARATOR);
  name = strtok(NULL, SIPRO_SEPARATOR);
  name[strlen(name) - 1] = 0;

  // Open the output file
  char output_asm_path[PATH_MAX + NAME_MAX + 1];
  memset(output_asm_path, 0, PATH_MAX + NAME_MAX + 1);
  snprintf(output_asm_path, PATH_MAX + NAME_MAX, "%s%s.%s", 
      ALGO2ASM_FOLDER, name, "asm");
  int output_fd = 0;
  if ((output_fd = open(output_asm_path, O_APPEND | O_RDWR)) < 0) {
    fprintf(stderr, "Failed to open %s file\n", output_asm_path);
    return EXIT_FAILURE;
  }

  // Write the beginning of the main
  dprintf(output_fd,
    "\n:main\n"
    "; Stack initialisation\n"
    "\tconst bp,stack\n"
    "\tconst sp,stack\n"
    "\tconst ax,2\n"
    "\tsub sp,ax\n"
  );
  
  // Extract the parameters
  char *parameters = strtok(NULL, SIPRO_SEPARATOR);
  parameters[strlen(parameters) - 1] = 0;

  // Split the parameters by , and convert them to int
  char *parameter = strtok(parameters, ",");
  dprintf(output_fd, "; Build parameters\n");
  while (parameter != NULL) {
    int parameter_int = 0;
    string_to_int(&parameter_int, parameter);
    dprintf(output_fd, 
      "\tconst ax,%d\n"
      "\tpush ax\n", parameter_int);
    parameter = strtok(NULL, ",");
  }

  // Call the function, print the result and create the stack zone
  dprintf(output_fd, 
    "; Call the %s function\n"
    "\tconst ax,%s\n"
    "\tcall ax\n"
    "; Get the result and print it\n"
    "\tpush ax\n"
    "\tcp ax,sp\n"
    "\tcallprintfd ax\n"
    "\tend\n"
    "\n; Stack zone\n"
    ":stack\n"
    "@int 0\n", name, name);
  
  if (close(output_fd) < 0) {
    fprintf(stderr, "Failed to close the %s file", output_asm_path);
    return EXIT_FAILURE;
  }

  compile_asm_and_run(output_asm_path);

  return EXIT_SUCCESS;
}

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
  *r = (int) v;
}

void compile_asm_and_run(const char *asm_path) {
  // Build output sipro path
  char output_sipro_path[PATH_MAX + NAME_MAX + 1];
  memset(output_sipro_path, 0, PATH_MAX + NAME_MAX + 1);
  snprintf(output_sipro_path, PATH_MAX + NAME_MAX + 1, "%s%s",
      ALGO2ASM_FOLDER, OUTPUT_SIPRO_NAME);

  // Execute asipro compilation
  int dev_null = 0;
  int child_status = 0;
  switch (fork()) {
    case -1:
      fprintf(stderr, "Can't fork to run asipro\n");
      exit(EXIT_FAILURE);
    
    case 0:
      if ((dev_null = open("/dev/null", O_WRONLY)) < 0) {
        fprintf(stderr, "Can't open /dev/null\n");
        exit(EXIT_FAILURE);
      }

      // Redirect stderr to /dev/null to not log asipro messages
      if (dup2(dev_null, STDERR_FILENO) < 0) {
        fprintf(stderr, "Can't redirect stderr to /dev/null\n");
        exit(EXIT_FAILURE);
      }

      // Run asipro
      execlp("asipro", "asipro", asm_path, output_sipro_path, NULL);
      exit(EXIT_SUCCESS);
    
    default:
      // Wait asipro and check status
      wait(&child_status);
      if (WEXITSTATUS(child_status) != EXIT_SUCCESS) {
        fprintf(stderr, "Error : asipro compilation failed\n");
        exit(EXIT_FAILURE);
      }

      // Run the sipro command
      execlp("sipro", "sipro", output_sipro_path, NULL);
  }
}
