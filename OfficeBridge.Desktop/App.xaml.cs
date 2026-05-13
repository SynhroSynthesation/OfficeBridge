using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace OfficeBridge.Desktop;

public partial class App : System.Windows.Application
{
    private static string LogPath =>
        Path.Combine(AppContext.BaseDirectory, "startup-error.log");

    private void Application_Startup(object sender, StartupEventArgs e)
    {
        try
        {
            WriteStartupLog("Application startup started.");

            var window = new MainWindow();
            window.Show();

            WriteStartupLog("MainWindow shown successfully.");
        }
        catch (Exception ex)
        {
            WriteException("Startup exception", ex);
            System.Windows.MessageBox.Show(
                "OfficeBridge failed to start. See startup-error.log in the application folder.",
                "Startup error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);

            Shutdown(-1);
        }
    }

    private void Application_DispatcherUnhandledException(
        object sender,
        DispatcherUnhandledExceptionEventArgs e)
    {
        WriteException("Unhandled dispatcher exception", e.Exception);

        System.Windows.MessageBox.Show(
            "OfficeBridge runtime error. See startup-error.log in the application folder.",
            "Runtime error",
            MessageBoxButton.OK,
            MessageBoxImage.Error);

        e.Handled = true;
        Shutdown(-2);
    }

    private static void WriteStartupLog(string message)
    {
        File.AppendAllText(
            LogPath,
            $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}{Environment.NewLine}");
    }

    private static void WriteException(string title, Exception ex)
    {
        File.AppendAllText(
            LogPath,
            $"{Environment.NewLine}[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {title}{Environment.NewLine}{ex}{Environment.NewLine}");
    }
}


