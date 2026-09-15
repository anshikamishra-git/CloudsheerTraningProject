public class hiringDTO {
    // Ye variable external JSON ke courseId ko store karega
    public String courseId;
    
    // Ye variable course ke name ko hold karega
    public String courseName;
    
    // Ye variable course ke current status ko hold karega
    public String status;

    // JSON string ko Apex object me convert karne ke liye static helper method
    public static hiringDTO parse(String json) {
        return (hiringDTO) System.JSON.deserialize(json, hiringDTO.class);
    }
}