using System;
using System.IO;
using System.Linq;

namespace OfficeBridge.Infrastructure
{
    public static class LibreOfficeDetector
    {
        public static bool TryFind(out string sofficePath)
        {
            string[] candidates =
            {
                @"C:\Program Files\LibreOffice\program\soffice.exe",
                @"C:\Program Files (x86)\LibreOffice\program\soffice.exe"
            };

            foreach (var path in candidates)
            {
                if (File.Exists(path))
                {
                    sofficePath = path;
                    return true;
                }
            }

            var pathEnv = Environment.GetEnvironmentVariable("PATH");

            if (!string.IsNullOrWhiteSpace(pathEnv))
            {
                var dirs = pathEnv.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries);

                foreach (var dir in dirs)
                {
                    try
                    {
                        var candidate = Path.Combine(dir, "soffice.exe");

                        if (File.Exists(candidate))
                        {
                            sofficePath = candidate;
                            return true;
                        }
                    }
                    catch
                    {
                        // Ignore invalid PATH entries.
                    }
                }
            }

            sofficePath = string.Empty;
            return false;
        }

        public static bool IsAvailable()
        {
            return TryFind(out _);
        }
    }
}