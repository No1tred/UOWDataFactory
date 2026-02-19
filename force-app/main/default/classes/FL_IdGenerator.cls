public class FL_IdGenerator {
    private static Integer counter = 0;

    public static Id generate(SObjectType sObjectType) {
        counter++;
        String keyPrefix = sObjectType.getDescribe().getKeyPrefix();
        String suffix = String.valueOf(counter).leftPad(12, '0');
        return (Id)(keyPrefix + suffix);
    }
}
