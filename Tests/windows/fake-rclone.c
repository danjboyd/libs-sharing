/* A stand-in rclone.exe for checking libs-sharing's rclone service on
   Windows (#198) without a real cloud account. It answers the commands
   GSSharingRclone runs and logs each call (arguments and the RCLONE_*
   environment) to rclone-calls.log beside itself.

     listremotes --long   one OneDrive remote, "fakedrive"
     lsf ...              exit 3 (the folder isn't there yet)
     copyto ...           JSON stats on stderr for FAKE_RCLONE_SECONDS (8)
     link ...             a fake https link on stdout
     deletefile ...       exit 0
     version              a version line

   Build (MSYS2 CLANG64): clang -O1 -static fake-rclone.c -o rclone.exe */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

static void log_call(int argc, char **argv)
{
  char path[MAX_PATH];
  char *slash;
  FILE *log;
  int i;

  GetModuleFileNameA(NULL, path, MAX_PATH);
  slash = strrchr(path, '\\');
  if (slash != NULL)
    {
      strcpy(slash + 1, "rclone-calls.log");
    }
  log = fopen(path, "a");
  if (log == NULL)
    {
      return;
    }
  fprintf(log, "call:");
  for (i = 1; i < argc; i++)
    {
      fprintf(log, " [%s]", argv[i]);
    }
  fprintf(log, "\n  RCLONE_CONFIG=%s RCLONE_ASK_PASSWORD=%s RCLONE_CONFIG_PASS=%s\n",
          getenv("RCLONE_CONFIG") ? getenv("RCLONE_CONFIG") : "(unset)",
          getenv("RCLONE_ASK_PASSWORD") ? getenv("RCLONE_ASK_PASSWORD") : "(unset)",
          getenv("RCLONE_CONFIG_PASS") ? "(set)" : "(unset)");
  fclose(log);
}

int main(int argc, char **argv)
{
  const char *command = argc > 1 ? argv[1] : "";

  log_call(argc, argv);
  if (strcmp(command, "version") == 0)
    {
      printf("rclone v1.68.0 (stand-in)\n");
      return 0;
    }
  if (strcmp(command, "listremotes") == 0)
    {
      printf("fakedrive: onedrive\n");
      return 0;
    }
  if (strcmp(command, "lsf") == 0)
    {
      fprintf(stderr, "directory not found\n");
      return 3;
    }
  if (strcmp(command, "copyto") == 0)
    {
      int seconds = getenv("FAKE_RCLONE_SECONDS") ? atoi(getenv("FAKE_RCLONE_SECONDS")) : 8;
      double total = 1000000.0;
      int i;

      for (i = 1; i <= seconds; i++)
        {
          Sleep(1000);
          fprintf(stderr,
                  "{\"level\":\"notice\",\"msg\":\"stats\",\"stats\":{\"bytes\":%.0f,\"totalBytes\":%.0f,\"transfers\":0}}\n",
                  total * i / seconds, total);
          fflush(stderr);
        }
      return 0;
    }
  if (strcmp(command, "link") == 0)
    {
      printf("https://example.com/s/fake-share-link\n");
      return 0;
    }
  if (strcmp(command, "deletefile") == 0)
    {
      return 0;
    }
  fprintf(stderr, "stand-in rclone: unknown command %s\n", command);
  return 1;
}
