import rs.etf.sab.operations.*;
import rs.etf.sab.student.*;
import rs.etf.sab.tests.TestHandler;
import rs.etf.sab.tests.TestRunner;

public class StudentMain {

    public static void main(String[] args) {

        ArticleOperations articleOperations = new vm190224_ArticleOperationsImplementation(); // Change this for your implementation (points will be negative if interfaces are not implemented).
        BuyerOperations buyerOperations = new vm190224_BuyerOperationsImplementation();
        CityOperations cityOperations = new vm190224_CityOperationsImplementation();
        GeneralOperations generalOperations = new vm190224_GeneralOperationsImplementation();
        OrderOperations orderOperations = new vm190224_OrderOperationsImplementation();
        ShopOperations shopOperations = new vm190224_ShopOperationsImplementation();
        TransactionOperations transactionOperations = new vm190224_TransactionOperationsImplementation();

        TestHandler.createInstance(
                articleOperations,
                buyerOperations,
                cityOperations,
                generalOperations,
                orderOperations,
                shopOperations,
                transactionOperations
        );

        TestRunner.runTests();
    }

}
