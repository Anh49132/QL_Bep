var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => Results.Ok(new { service = "Notification.Service", week = 1 }));
app.MapGet("/health", () => Results.Ok(new { service = "Notification.Service", status = "ok" }));

app.Run();
