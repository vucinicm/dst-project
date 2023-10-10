package rs.etf.sab.student;

import rs.etf.sab.operations.ArticleOperations;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class vm190224_ArticleOperationsImplementation implements ArticleOperations {

    final Connection connection = DB.getInstance().getConnection();

    @Override
    public int createArticle(int shopId, java.lang.String articleName, int articlePrice) {
        final String query = "INSERT INTO artikal(naziv, cena, kolicina_na_stanju, id_prodavnice) VALUES(?, ?, 0, ?)";

        try (PreparedStatement ps = connection.prepareStatement(query, PreparedStatement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, articleName);
            ps.setInt(2, articlePrice);
            ps.setInt(3, shopId);
            ps.executeUpdate();
            final ResultSet generatedKeys = ps.getGeneratedKeys();
            if (generatedKeys.next())
                return generatedKeys.getInt(1);
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

}
