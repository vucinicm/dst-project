package rs.etf.sab.student;

import rs.etf.sab.operations.GeneralOperations;
import rs.etf.sab.operations.OrderOperations;

import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;

public class vm190224_OrderOperationsImplementation implements OrderOperations {

    private final GeneralOperations generalOperations = new vm190224_GeneralOperationsImplementation();
    final Connection connection = DB.getInstance().getConnection();

    @Override
    public int addArticle(int orderId, int articleId, int count) {
        final String query = "INSERT INTO artikal_pripada_porudzbini(id_porudzbine, id_artikla, kolicina) VALUES(?, ?, ?)";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ps.setInt(2, articleId);
            ps.setInt(3, count);
            ps.executeUpdate();
            return 1;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return 0;
    }

    @Override
    public int removeArticle(int orderId, int articleId) {
        final String query = "DELETE FROM artikal_pripada_porudzbini WHERE id_porudzbine = ? AND id_artikla = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ps.setInt(2, articleId);
            ps.executeUpdate();
            return 1;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public List<Integer> getItems(int orderId) {
        final String query = "SELECT id_artikla FROM artikal_pripada_porudzbini WHERE id_porudzbine = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ResultSet rs = ps.executeQuery();
            List<Integer> items = new ArrayList<>();
            while (rs.next()) {
                items.add(rs.getInt(1));
            }
            return items;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public int completeOrder(int orderId) {
        final String query = "{ CALL SP_COMPLETE_ORDER(?, ?, ?, ?) }";

        try (CallableStatement cs = connection.prepareCall(query)) {
            cs.setInt(1, orderId);
            java.sql.Date date = new java.sql.Date(generalOperations.getCurrentTime().getTimeInMillis());
            cs.setDate(2, date);

            cs.registerOutParameter(3, Types.INTEGER);
            cs.registerOutParameter(4, Types.VARCHAR);

            cs.execute();

            final int status = cs.getInt(3);
            final String message = cs.getString(4);

            if (status != 0) {
                System.out.println(message);
                return -1;
            } else {
                return 1;
            }

        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return -1;
        }
    }

    @Override
    public BigDecimal getFinalPrice(int orderId) {
        final String query = "SELECT krajnja_cena FROM porudzbina WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getBigDecimal(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return BigDecimal.valueOf(-1);
    }

    @Override
    public BigDecimal getDiscountSum(int orderId) {
        final String query = "{ CALL SP_GET_DISCOUNT_SUM(?, ?) }";

        try (CallableStatement cs = connection.prepareCall(query)) {
            cs.setInt(1, orderId);

            cs.registerOutParameter(2, Types.DECIMAL);

            cs.execute();

            return cs.getBigDecimal(2).setScale(3);

        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return BigDecimal.valueOf(-1);
        }
    }

    @Override
    public String getState(int orderId) {
        final String query = "SELECT stanje FROM porudzbina WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getString(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public Calendar getSentTime(int orderId) {
        final String query = "SELECT vreme_slanja FROM porudzbina WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                final Date date = rs.getDate(1);
                if (rs.wasNull()) {
                    return null;
                }
                Calendar calendar = Calendar.getInstance();
                calendar.setTime(date);
                return calendar;
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public Calendar getRecievedTime(int orderId) {
        final String query = "SELECT vreme_prijema FROM porudzbina WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                final Date date = rs.getDate(1);
                if (rs.wasNull()) {
                    return null;
                }
                Calendar calendar = Calendar.getInstance();
                calendar.setTime(date);
                return calendar;
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public int getBuyer(int orderId) {
        final String query = "SELECT id_kupca FROM porudzbina WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public int getLocation(int orderId) {
        final String query = "SELECT trenutni_grad FROM porudzbina WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                final int location = rs.getInt(1);
                if (rs.wasNull()) {
                    return -1;
                }
                return location;
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }
}
