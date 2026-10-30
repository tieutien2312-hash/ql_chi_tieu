package com.example.ql_chi_tieu;

import android.app.Notification;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class BankNotificationListenerService extends NotificationListenerService {

    private static final String TAG = "BankNotifListener";

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        String packageName = sbn.getPackageName();
        Notification notification = sbn.getNotification();
        if (notification == null || notification.extras == null) return;

        Bundle extras = notification.extras;
        String title = extras.getString(Notification.EXTRA_TITLE, "");
        String text = extras.getString(Notification.EXTRA_TEXT, "");
        String bigText = extras.getString(Notification.EXTRA_BIG_TEXT, "");
        String summaryText = extras.getString(Notification.EXTRA_SUMMARY_TEXT, "");

        Log.d(TAG, "INCOMING NOTIF -> Pkg: " + packageName + " | Title: " + title + " | Text: " + text + " | BigText: " + bigText);

        if (isSupportedApp(packageName, title, text, bigText, summaryText)) {
            parseAndSaveTransaction(packageName, title, text, bigText, summaryText);
        }
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        // Not needed
    }

    private boolean isSupportedApp(String pkg, String title, String text, String bigText, String summaryText) {
        if (pkg == null) return false;
        String lowerPkg = pkg.toLowerCase();
        String lowerCombined = (title + " " + text + " " + bigText + " " + summaryText).toLowerCase();

        return lowerPkg.contains("vietcombank") ||
               lowerPkg.contains("vcb") ||
               lowerPkg.contains("mbmobile") ||
               lowerPkg.contains("agribank") ||
               lowerPkg.contains("bidv") ||
               lowerPkg.contains("momo") ||
               lowerPkg.contains("mservice") ||
               lowerPkg.contains("zalopay") ||
               lowerPkg.contains("techcombank") ||
               lowerPkg.contains("acb") ||
               lowerPkg.contains("tpbank") ||
               lowerPkg.contains("vpbank") ||
               lowerPkg.contains("sacombank") ||
               lowerCombined.contains("momo") ||
               lowerCombined.contains("zalopay") ||
               lowerCombined.contains("bien dong so du") ||
               lowerCombined.contains("biến động số dư") ||
               lowerCombined.contains("so du") ||
               lowerCombined.contains("số dư") ||
               lowerCombined.contains("tai khoan") ||
               lowerCombined.contains("tài khoản") ||
               lowerCombined.contains("thanh toan") ||
               lowerCombined.contains("thanh toán") ||
               lowerCombined.contains("nhan tien") ||
               lowerCombined.contains("nhận tiền") ||
               lowerCombined.contains("giao dich") ||
               lowerCombined.contains("giao dịch");
    }

    private String detectCategory(String type, String text) {
        if (text == null) return type.equals("INCOME") ? "Lương" : "Khác";
        String lower = text.toLowerCase();

        if (type.equals("INCOME")) {
            if (lower.contains("thuong") || lower.contains("thưởng")) return "Tiền thưởng";
            return "Lương";
        }

        if (lower.contains("sieu thi") || lower.contains("siêu thị") || lower.contains("shopee") || lower.contains("lazada") || lower.contains("tiki") || lower.contains("coopmart") || lower.contains("winmart") || lower.contains("circle k") || lower.contains("gs25") || lower.contains("mua sam") || lower.contains("mua sắm")) {
            return "Mua sắm";
        }
        if (lower.contains("highlands") || lower.contains("phuc long") || lower.contains("starbucks") || lower.contains("coffee") || lower.contains("grabfood") || lower.contains("shopeefood") || lower.contains("baemin") || lower.contains("quan an") || lower.contains("quán ăn") || lower.contains("nha hang") || lower.contains("nhà hàng") || lower.contains("bun") || lower.contains("pho") || lower.contains("phở") || lower.contains("com") || lower.contains("cơm") || lower.contains("ca phe") || lower.contains("cà phê")) {
            return "Ăn uống";
        }
        if (lower.contains("grab") || lower.contains("be ") || lower.contains("gojek") || lower.contains("vato") || lower.contains("mai linh") || lower.contains("taxi") || lower.contains("xang") || lower.contains("xăng") || lower.contains("petrolimex") || lower.contains("ve xe") || lower.contains("vé xe")) {
            return "Di chuyển";
        }
        if (lower.contains("dien") || lower.contains("điện") || lower.contains("nuoc") || lower.contains("nước") || lower.contains("internet") || lower.contains("fpt") || lower.contains("viettel") || lower.contains("vnpt") || lower.contains("truyen hinh") || lower.contains("truyền hình") || lower.contains("hoa don") || lower.contains("hóa đơn")) {
            return "Hóa đơn";
        }
        if (lower.contains("game") || lower.contains("film") || lower.contains("cinema") || lower.contains("cgv") || lower.contains("lotte") || lower.contains("billiards") || lower.contains("karaoke")) {
            return "Giải trí";
        }
        if (lower.contains("benh vien") || lower.contains("bệnh viện") || lower.contains("nha thuoc") || lower.contains("nhà thuốc") || lower.contains("pharmacity") || lower.contains("long chau") || lower.contains("long châu") || lower.contains("kham") || lower.contains("khám")) {
            return "Sức khỏe";
        }
        if (lower.contains("hoc phi") || lower.contains("học phí") || lower.contains("truong") || lower.contains("trường") || lower.contains("sach") || lower.contains("sách")) {
            return "Học tập";
        }

        return "Khác";
    }

    private void parseAndSaveTransaction(String pkg, String title, String text, String bigText, String summaryText) {
        String combined = (title + " " + text + " " + bigText + " " + summaryText).trim();
        if (combined.isEmpty()) return;

        // Determine bank / e-wallet name
        String lowerPkg = pkg.toLowerCase();
        String lowerCombined = combined.toLowerCase();

        String bankName = "Ngân hàng/Ví";
        if (lowerPkg.contains("vietcombank") || lowerPkg.contains("vcb") || lowerCombined.contains("vietcombank")) bankName = "Vietcombank";
        else if (lowerPkg.contains("mbmobile") || lowerCombined.contains("mb bank") || lowerCombined.contains("mbbank")) bankName = "MB Bank";
        else if (lowerPkg.contains("agribank") || lowerCombined.contains("agribank")) bankName = "Agribank";
        else if (lowerPkg.contains("bidv") || lowerCombined.contains("bidv")) bankName = "BIDV";
        else if (lowerPkg.contains("momo") || lowerPkg.contains("mservice") || lowerCombined.contains("momo")) bankName = "Ví Momo";
        else if (lowerPkg.contains("zalopay") || lowerCombined.contains("zalopay")) bankName = "ZaloPay";
        else if (lowerPkg.contains("techcombank") || lowerCombined.contains("techcombank")) bankName = "Techcombank";

        // Determine transaction type (INCOME or EXPENSE)
        String type = "EXPENSE";
        if (lowerCombined.contains("+") || lowerCombined.contains("nhan tien") || lowerCombined.contains("nhận tiền") || lowerCombined.contains("cong") || lowerCombined.contains("cộng") || lowerCombined.contains("nap tien") || lowerCombined.contains("nạp tiền")) {
            type = "INCOME";
        }

        // Extract transaction amount
        double amount = extractAmount(combined);
        if (amount <= 0) {
            Log.d(TAG, "Could not extract valid amount from notification: " + combined);
            return;
        }

        // Extract balance after
        double balanceAfter = extractBalance(combined);

        // Extract account / phone number
        String accountNumber = extractAccountNumber(combined);
        if (accountNumber.isEmpty()) {
            accountNumber = "Chính";
        }

        String currentTime = new SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault()).format(new Date());

        // Open or create SQLite database safely
        try {
            Context context = getApplicationContext();
            File dbFile = context.getDatabasePath("ql_chi_tieu.db");
            if (!dbFile.getParentFile().exists()) {
                dbFile.getParentFile().mkdirs();
            }

            SQLiteDatabase db = SQLiteDatabase.openOrCreateDatabase(dbFile, null);

            // Ensure tables exist
            db.execSQL("CREATE TABLE IF NOT EXISTS accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, bankName TEXT NOT NULL, accountName TEXT NOT NULL, accountNumber TEXT NOT NULL, balance REAL NOT NULL, createdAt TEXT NOT NULL)");
            db.execSQL("CREATE TABLE IF NOT EXISTS transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, accountId INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, balanceAfter REAL NOT NULL, description TEXT NOT NULL, transactionTime TEXT NOT NULL, source TEXT NOT NULL, category TEXT)");

            // 1. Find or create account
            long accountId = -1;
            Cursor cursor = db.rawQuery(
                "SELECT id FROM accounts WHERE bankName = ? AND (accountNumber LIKE ? OR ? LIKE '%' || accountNumber || '%')",
                new String[]{bankName, "%" + accountNumber + "%", accountNumber}
            );
            if (cursor.moveToFirst()) {
                accountId = cursor.getLong(0);
            }
            cursor.close();

            if (accountId == -1) {
                ContentValues accValues = new ContentValues();
                accValues.put("bankName", bankName);
                accValues.put("accountName", bankName + " (" + accountNumber + ")");
                accValues.put("accountNumber", accountNumber);
                accValues.put("balance", balanceAfter > 0 ? balanceAfter : amount);
                accValues.put("createdAt", currentTime);
                accountId = db.insert("accounts", null, accValues);
                Log.d(TAG, "Auto created new account ID: " + accountId + " for " + bankName);
            }

            // 2. Insert transaction with smart detected category
            ContentValues txValues = new ContentValues();
            txValues.put("accountId", accountId);
            txValues.put("type", type);
            txValues.put("amount", amount);
            txValues.put("balanceAfter", balanceAfter);
            txValues.put("description", combined);
            txValues.put("transactionTime", currentTime);
            txValues.put("source", "notification");
            txValues.put("category", detectCategory(type, combined));
            db.insert("transactions", null, txValues);

            // 3. Update account balance
            if (balanceAfter > 0) {
                db.execSQL("UPDATE accounts SET balance = ? WHERE id = ?", new Object[]{balanceAfter, accountId});
            } else {
                String sign = type.equals("INCOME") ? "+" : "-";
                db.execSQL("UPDATE accounts SET balance = balance " + (sign.equals("+") ? "+" : "-") + " ? WHERE id = ?", new Object[]{amount, accountId});
            }

            db.close();
            Log.d(TAG, "Successfully saved transaction! Bank: " + bankName + " | Type: " + type + " | Amount: " + amount + " | BalanceAfter: " + balanceAfter);

        } catch (Exception e) {
            Log.e(TAG, "Error saving notification to SQLite database", e);
        }
    }

    private double extractAmount(String text) {
        try {
            // 1. Try explicit signed currency pattern like +2,000VND or -50,000đ
            Pattern signedCurrency = Pattern.compile("([+-])\\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]+)?|[0-9]+)\\s*(?:VND|vnd|đ|VNĐ|VNđ)?", Pattern.CASE_INSENSITIVE);
            Matcher mSigned = signedCurrency.matcher(text);
            if (mSigned.find()) {
                String match = mSigned.group(2);
                if (match != null) {
                    String clean = match.replace(".", "").replace(",", "");
                    double val = Double.parseDouble(clean);
                    if (val >= 1000) return val;
                }
            }

            // 2. Try explicit amount keywords
            Pattern pGd = Pattern.compile("(?:GD|Giao dịch|Số tiền|Amount|thanh toán|chuyển|nhận)\\s*[:=]?\\s*([+-]?)\\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]+)?|[0-9]+)", Pattern.CASE_INSENSITIVE);
            Matcher mGd = pGd.matcher(text);
            if (mGd.find()) {
                String match = mGd.group(2);
                if (match != null) {
                    String clean = match.replace(".", "").replace(",", "");
                    double val = Double.parseDouble(clean);
                    if (val >= 1000) return val;
                }
            }

            // 3. Fallback: find any number followed by VND, đ, VNĐ
            Pattern pCurrency = Pattern.compile("([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]+)?|[0-9]+)\\s*(?:VND|vnd|đ|VNĐ|VNđ)", Pattern.CASE_INSENSITIVE);
            Matcher mCurrency = pCurrency.matcher(text);
            while (mCurrency.find()) {
                String match = mCurrency.group(1);
                if (match != null) {
                    String clean = match.replace(".", "").replace(",", "");
                    double val = Double.parseDouble(clean);
                    if (val >= 1000) return val;
                }
            }

            // 4. Fallback: find any 4-9 digit number
            Pattern pNum = Pattern.compile("\\b([0-9]{4,9})\\b");
            Matcher mNum = pNum.matcher(text);
            if (mNum.find()) {
                String match = mNum.group(1);
                double val = Double.parseDouble(match);
                if (val >= 1000) return val;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error extracting amount", e);
        }
        return 0.0;
    }

    private double extractBalance(String text) {
        try {
            Pattern p = Pattern.compile("(?:SD|So du|Số dư|SD cuối|So du cuoi|Số dư cuối)\\s*[:=]?\\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]+)?|[0-9]+)", Pattern.CASE_INSENSITIVE);
            Matcher m = p.matcher(text);
            if (m.find()) {
                String match = m.group(1);
                if (match != null) {
                    String clean = match.replace(".", "").replace(",", "");
                    return Double.parseDouble(clean);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error extracting balance", e);
        }
        return 0.0;
    }

    private String extractAccountNumber(String text) {
        try {
            Pattern pattern = Pattern.compile("(?:TK|STK|tài khoản|ví|sđt|account|phone)[^0-9]*([0-9*]{4,12})", Pattern.CASE_INSENSITIVE);
            Matcher matcher = pattern.matcher(text);
            if (matcher.find()) {
                return matcher.group(1);
            }
        } catch (Exception e) {
            // ignore
        }
        return "Chính";
    }
}
