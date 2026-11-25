using Microsoft.EntityFrameworkCore;
using Order.Api.Data;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<RestaurantDbContext>(options => options
    .UseNpgsql(builder.Configuration.GetConnectionString("RestaurantDb"))
    .UseSeeding(SampleData.Seed)
    .UseAsyncSeeding(SampleData.SeedAsync));
builder.Services.AddProblemDetails();
var app = builder.Build();
app.UseExceptionHandler();
app.UseStaticFiles();

// Lệnh khởi tạo riêng: không bắt API thường phải migrate DB mỗi lần khởi động.
if (args.Contains("--migrate"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<RestaurantDbContext>();
    await db.Database.MigrateAsync();
    app.Logger.LogInformation("Database migration and sample data completed.");
    return;
}

app.MapGet("/", () => Results.Ok(new { service = "Order.Api", week = 1 }));
app.MapGet("/health", () => Results.Ok(new { service = "Order.Api", status = "ok" }));
app.MapGet("/menu", async (RestaurantDbContext db, CancellationToken cancellationToken) =>
    Results.Ok(await db.MenuItems.AsNoTracking()
        .Where(x => x.IsAvailable)
        .OrderBy(x => x.Category).ThenBy(x => x.Id)
        .Select(x => new { x.Id, x.Name, x.Price, x.Category, x.ImageUrl, x.ImageAlt, x.ImageSource })
        .ToListAsync(cancellationToken)));

app.Run();
