namespace Order.Api.Models;

public sealed class TableSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public int TableNumber { get; set; }
    public RestaurantTable Table { get; set; } = null!;
    public required string CustomerCode { get; set; }
    public DateTimeOffset StartedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? EndedAt { get; set; }
}
