using Microsoft.EntityFrameworkCore;
using Order.Api.Models;
using RestaurantOrder = Order.Api.Models.Order;

namespace Order.Api.Data;

public sealed class RestaurantDbContext(DbContextOptions<RestaurantDbContext> options) : DbContext(options)
{
    public DbSet<MenuItem> MenuItems => Set<MenuItem>();
    public DbSet<RestaurantTable> RestaurantTables => Set<RestaurantTable>();
    public DbSet<TableSession> TableSessions => Set<TableSession>();
    public DbSet<RestaurantOrder> Orders => Set<RestaurantOrder>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var menu = modelBuilder.Entity<MenuItem>();
        // 1..10 dành cho seed; món tạo mới dùng sequence từ 1000 để tránh trùng mã.
        menu.Property(x => x.Id).HasIdentityOptions(startValue: 1000);
        menu.Property(x => x.Name).HasMaxLength(150);
        menu.Property(x => x.Category).HasMaxLength(80);
        menu.Property(x => x.Price).HasPrecision(18, 2);
        menu.Property(x => x.ImageUrl).HasMaxLength(500);
        menu.Property(x => x.ImageAlt).HasMaxLength(300);
        menu.Property(x => x.ImageSource).HasMaxLength(300);
        menu.ToTable(t => t.HasCheckConstraint("CK_MenuItems_Price", "\"Price\" >= 0"));

        var table = modelBuilder.Entity<RestaurantTable>();
        table.HasKey(x => x.Number);
        table.Property(x => x.Number).ValueGeneratedNever();
        table.Property(x => x.Name).HasMaxLength(80);
        table.ToTable(t => t.HasCheckConstraint("CK_RestaurantTables_Number", "\"Number\" > 0"));

        var session = modelBuilder.Entity<TableSession>();
        session.Property(x => x.CustomerCode).HasMaxLength(80);
        session.HasOne(x => x.Table).WithMany().HasForeignKey(x => x.TableNumber).OnDelete(DeleteBehavior.Restrict);
        session.HasAlternateKey(x => new { x.Id, x.TableNumber });
        session.ToTable(t => t.HasCheckConstraint("CK_TableSessions_Times", "\"EndedAt\" IS NULL OR \"EndedAt\" >= \"StartedAt\""));

        var order = modelBuilder.Entity<RestaurantOrder>();
        order.Property(x => x.Code).HasMaxLength(32);
        order.HasIndex(x => x.Code).IsUnique();
        order.Property(x => x.CustomerCode).HasMaxLength(80);
        order.Property(x => x.Notes).HasMaxLength(1000);
        order.Property(x => x.Status).HasConversion<string>().HasMaxLength(16);
        order.Property(x => x.Total).HasPrecision(18, 2);
        order.HasOne(x => x.TableSession).WithMany()
            .HasForeignKey(x => new { x.TableSessionId, x.TableNumber })
            .HasPrincipalKey(x => new { x.Id, x.TableNumber }).OnDelete(DeleteBehavior.Restrict);
        order.HasIndex(x => new { x.TableSessionId, x.CreatedAt });
        order.ToTable(t =>
        {
            t.HasCheckConstraint("CK_Orders_Total", "\"Total\" >= 0");
            t.HasCheckConstraint("CK_Orders_Status", "\"Status\" IN ('Pending', 'Preparing', 'Ready', 'Cancelled')");
        });

        var item = modelBuilder.Entity<OrderItem>();
        item.Property(x => x.MenuItemName).HasMaxLength(150);
        item.Property(x => x.UnitPrice).HasPrecision(18, 2);
        item.Property(x => x.Notes).HasMaxLength(1000);
        item.HasOne(x => x.Order).WithMany(x => x.Items).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
        item.HasOne(x => x.MenuItem).WithMany().HasForeignKey(x => x.MenuItemId).OnDelete(DeleteBehavior.Restrict);
        item.ToTable(t =>
        {
            t.HasCheckConstraint("CK_OrderItems_Quantity", "\"Quantity\" > 0");
            t.HasCheckConstraint("CK_OrderItems_UnitPrice", "\"UnitPrice\" >= 0");
        });
    }
}
