var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();
app.MapGet("/health", () => Results.Ok(new { service = "Restaurant.Web", status = "ok" }));
app.MapGet("/config", () => Results.Ok(new
{
    orderApiUrl = app.Configuration["Services:OrderApiUrl"],
    notificationUrl = app.Configuration["Services:NotificationUrl"]
}));

app.Run();
