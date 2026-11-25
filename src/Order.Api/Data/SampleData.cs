using Microsoft.EntityFrameworkCore;
using Order.Api.Models;

namespace Order.Api.Data;

public static class SampleData
{
    // EF gọi các hàm này dưới migration lock. Chỉ bổ sung mã thiếu, không ghi đè dữ liệu đã sửa.
    public static void Seed(DbContext context, bool _)
    {
        AddMissing(context, context.Set<MenuItem>().Select(x => x.Id).ToHashSet(),
            context.Set<RestaurantTable>().Select(x => x.Number).ToHashSet());
        context.SaveChanges();
    }

    public static async Task SeedAsync(DbContext context, bool _, CancellationToken cancellationToken)
    {
        var menuIds = (await context.Set<MenuItem>().Select(x => x.Id).ToListAsync(cancellationToken)).ToHashSet();
        var tableNumbers = (await context.Set<RestaurantTable>().Select(x => x.Number).ToListAsync(cancellationToken)).ToHashSet();
        AddMissing(context, menuIds, tableNumbers);
        await context.SaveChangesAsync(cancellationToken);
    }

    private static void AddMissing(DbContext context, HashSet<int> menuIds, HashSet<int> tableNumbers)
    {
        MenuItem[] menu =
        [
            new() { Id = 1, Name = "Cơm gà", Price = 45000m, Category = "Cơm" },
            new() { Id = 2, Name = "Cơm sườn", Price = 50000m, Category = "Cơm" },
            new() { Id = 3, Name = "Cơm bò xào", Price = 55000m, Category = "Cơm" },
            new() { Id = 4, Name = "Phở bò", Price = 50000m, Category = "Món nước" },
            new() { Id = 5, Name = "Bún chả", Price = 45000m, Category = "Bún" },
            new() { Id = 6, Name = "Mì xào rau củ", Price = 40000m, Category = "Mì" },
            new() { Id = 7, Name = "Gỏi cuốn", Price = 30000m, Category = "Khai vị" },
            new() { Id = 8, Name = "Khoai tây chiên", Price = 25000m, Category = "Khai vị" },
            new() { Id = 9, Name = "Trà đào", Price = 25000m, Category = "Đồ uống" },
            new() { Id = 10, Name = "Nước chanh", Price = 20000m, Category = "Đồ uống" }
        ];
        context.AddRange(menu.Where(x => !menuIds.Contains(x.Id)));
        context.AddRange(Enumerable.Range(1, 5).Where(x => !tableNumbers.Contains(x))
            .Select(x => new RestaurantTable { Number = x, Name = $"Bàn {x}" }));
    }
}
