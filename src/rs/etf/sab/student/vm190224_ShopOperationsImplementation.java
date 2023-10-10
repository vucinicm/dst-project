package rs.etf.sab.student;

import rs.etf.sab.operations.ShopOperations;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public class vm190224_ShopOperationsImplementation implements ShopOperations {

    final Connection connection = DB.getInstance().getConnection();

    @Override
    public int createShop(String name, String cityName) {
        final String query = "INSERT INTO prodavnica(naziv, id_grada, popust) VALUES(?, (SELECT id FROM grad WHERE naziv = ?), null)";

        try (PreparedStatement ps = connection.prepareStatement(query, PreparedStatement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, name);
            ps.setString(2, cityName);
            ps.executeUpdate();
            final ResultSet generatedKeys = ps.getGeneratedKeys();
            if (generatedKeys.next())
                return generatedKeys.getInt(1);
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public int setCity(int shopId, String cityName) {
        final String query = "UPDATE prodavnica SET id_grada = (SELECT id FROM grad WHERE naziv = ?) WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setString(1, cityName);
            ps.setInt(2, shopId);
            ps.executeUpdate();
            return 1;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public int getCity(int shopId) {
        final String query = "SELECT id_grada FROM prodavnica WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, shopId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public int setDiscount(int shopId, int discountPercentage) {
        final String query = "UPDATE prodavnica SET popust = ? WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, discountPercentage);
            ps.setInt(2, shopId);
            ps.executeUpdate();
            return 1;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public int increaseArticleCount(int articleId, int increment) {
        String query = "UPDATE artikal SET kolicina_na_stanju = kolicina_na_stanju + ? WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, increment);
            ps.setInt(2, articleId);
            ps.executeUpdate();
        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return -1;
        }

        return getArticleCount(articleId);
    }

    @Override
    public int getArticleCount(int articleId) {
        String query = "SELECT kolicina_na_stanju FROM artikal WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, articleId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public List<Integer> getArticles(int shopId) {
        final String query = "SELECT id FROM artikal WHERE id_prodavnice = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, shopId);
            final ResultSet rs = ps.executeQuery();
            final List<Integer> articles = new ArrayList<>();
            while (rs.next()) {
                articles.add(rs.getInt(1));
            }
            return articles;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
        return null;
    }

    @Override
    public int getDiscount(int shopId) {
        final String query = "SELECT popust FROM prodavnica WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, shopId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return 0;
    }
}
