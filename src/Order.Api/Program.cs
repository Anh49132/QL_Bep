var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => Results.Ok(new { service = "Order.Api", week = 1 }));
app.MapGet("/health", () => Results.Ok(new { service = "Order.Api", status = "ok" }));

app.Run();
