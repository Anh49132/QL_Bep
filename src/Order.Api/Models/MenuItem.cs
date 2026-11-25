namespace Order.Api.Models;

public sealed class MenuItem
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public decimal Price { get; set; }
    public required string Category { get; set; }
    public string ImageUrl { get; set; } = "/images/menu-placeholder.svg";
    public string ImageAlt { get; set; } = "Hình minh họa đĩa thức ăn, chưa phải ảnh món thực tế";
    public string ImageSource { get; set; } = "Bếp Nhà — minh họa SVG tự tạo";
    public bool IsAvailable { get; set; } = true;
}
