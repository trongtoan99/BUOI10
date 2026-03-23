CREATE TABLE Phong (
    MaPhong        VARCHAR2(10) CONSTRAINT pk_phong PRIMARY KEY,
    LoaiPhong      VARCHAR2(20),
    TrangThai      VARCHAR2(20) CHECK (TrangThai IN ('TRONG', 'DA_THUE', 'BAO_TRI')),
    GiaTheoGio     NUMBER(15,2),
    GiaTheoNgay    NUMBER(15,2),
    SoNguoiToiDa   NUMBER(2)
);

CREATE TABLE KhachHang (
    MaKH      VARCHAR2(10) CONSTRAINT pk_khachhang PRIMARY KEY,
    HoTen     VARCHAR2(100),
    CCCD      VARCHAR2(20),
    SoDT      VARCHAR2(15),
    Email     VARCHAR2(50),
    QuocTich  VARCHAR2(50)
);

CREATE TABLE HoaDon (
    MaHD      VARCHAR2(10) CONSTRAINT pk_hoadon PRIMARY KEY,
    MaKH      VARCHAR2(10) REFERENCES KhachHang(MaKH),
    MaPhong   VARCHAR2(10) REFERENCES Phong(MaPhong),
    NgayNhan  DATE,
    NgayTra   DATE,
    SoNguoi   NUMBER(3),
    TongTien  NUMBER(15,2),
    TrangThai VARCHAR2(20) CHECK (TrangThai IN ('CHO_NHAN', 'DANG_O', 'DA_TRA', 'HUY'))
);

CREATE TABLE ChiPhiPhuThu (
    MaCP      VARCHAR2(10) CONSTRAINT pk_chiphiphuthu PRIMARY KEY,
    MaHD      VARCHAR2(10) REFERENCES HoaDon(MaHD),
    MoTa      VARCHAR2(200),
    SoTien    NUMBER(15,2),
    ThoiGian  DATE
);

CREATE TABLE LichSuPhong (
    MaLS      VARCHAR2(10) CONSTRAINT pk_lichsuphong PRIMARY KEY,
    MaPhong   VARCHAR2(10) REFERENCES Phong(MaPhong),
    MaHD      VARCHAR2(10) REFERENCES HoaDon(MaHD),
    NgayNhan  DATE,
    NgayTra   DATE,
    GhiChu    VARCHAR2(200)
);

--A
CREATE OR REPLACE TRIGGER trg_DatPhong
BEFORE INSERT ON HoaDon
FOR EACH ROW
DECLARE
    v_dem_kh     NUMBER := 0;
    v_dem_phong  NUMBER := 0;
    v_trangthai  VARCHAR2(20);
    v_songuoi    NUMBER := 0;
    v_giatheonday NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_dem_kh FROM KhachHang WHERE MaKH = :NEW.MaKH;
    IF v_dem_kh = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'MaKH khong ton tai');
    END IF;
    SELECT COUNT(*) INTO v_dem_phong FROM Phong WHERE MaPhong = :NEW.MaPhong;
    IF v_dem_phong = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'MaPhong khong ton tai');
    END IF;
    SELECT TrangThai, SoNguoiToiDa INTO v_trangthai, v_songuoi
    FROM Phong WHERE MaPhong = :NEW.MaPhong;
    IF v_trangthai <> 'TRONG' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Phong khong o trang thai TRONG');
    END IF;
    IF :NEW.SoNguoi > v_songuoi THEN
        RAISE_APPLICATION_ERROR(-20004, 'SoNguoi vuot qua SoNguoiToiDa');
    END IF;
    IF :NEW.NgayNhan >= :NEW.NgayTra OR :NEW.NgayNhan < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20005, 'NgayNhan hoac NgayTra khong hop le');
    END IF;
    SELECT GiaTheoNgay INTO v_giatheonday FROM Phong WHERE MaPhong = :NEW.MaPhong;
    :NEW.TongTien := (:NEW.NgayTra - :NEW.NgayNhan) * v_giatheonday;
    UPDATE Phong SET TrangThai = 'DA_THUE' WHERE MaPhong = :NEW.MaPhong;
END trg_DatPhong;
/
DELETE FROM LichSuPhong;
DELETE FROM ChiPhiPhuThu;
DELETE FROM HoaDon;
DELETE FROM Phong;
DELETE FROM KhachHang;
COMMIT;
-- test 
-- Insert lai du lieu mau
INSERT INTO Phong VALUES ('P01', 'VIP', 'TRONG', 500000, 2000000, 2);
INSERT INTO KhachHang VALUES ('KH01', 'Nguyen Van A', '123456789', '0911111111', 'nva@gmail.com', 'Viet Nam');
COMMIT;

-- TH1: Insert hop le
INSERT INTO HoaDon (MaHD, MaKH, MaPhong, NgayNhan, NgayTra, SoNguoi, TongTien, TrangThai)
VALUES ('HD01', 'KH01', 'P01',
    TO_DATE('25/04/2026', 'DD/MM/YYYY'),
    TO_DATE('28/04/2026', 'DD/MM/YYYY'),
    2, NULL, 'CHO_NHAN');
COMMIT;

-- TH2: MaKH khong ton tai -> bao loi
INSERT INTO HoaDon (MaHD, MaKH, MaPhong, NgayNhan, NgayTra, SoNguoi, TongTien, TrangThai)
VALUES ('HD02', 'KH99', 'P01',
    TO_DATE('25/04/2026', 'DD/MM/YYYY'),
    TO_DATE('28/04/2026', 'DD/MM/YYYY'),
    2, NULL, 'CHO_NHAN');

-- TH3: Phong khong o trang thai TRONG -> bao loi
INSERT INTO HoaDon (MaHD, MaKH, MaPhong, NgayNhan, NgayTra, SoNguoi, TongTien, TrangThai)
VALUES ('HD03', 'KH01', 'P01',
    TO_DATE('25/04/2026', 'DD/MM/YYYY'),
    TO_DATE('28/04/2026', 'DD/MM/YYYY'),
    2, NULL, 'CHO_NHAN');
    
--B 
CREATE OR REPLACE TRIGGER trg_CapNhatTrangThaiHD
BEFORE UPDATE OF TrangThai ON HoaDon
FOR EACH ROW
DECLARE
    v_dem NUMBER := 0;
BEGIN
    IF :OLD.TrangThai = 'CHO_NHAN' AND
       :NEW.TrangThai <> 'DANG_O' AND :NEW.TrangThai <> 'HUY' THEN
        RAISE_APPLICATION_ERROR(-20001, 'CHO_NHAN chi chuyen sang DANG_O hoac HUY');
    END IF;

    IF :OLD.TrangThai = 'DANG_O' AND :NEW.TrangThai <> 'DA_TRA' THEN
        RAISE_APPLICATION_ERROR(-20002, 'DANG_O chi chuyen sang DA_TRA');
    END IF;

    IF :OLD.TrangThai = 'DA_TRA' OR :OLD.TrangThai = 'HUY' THEN
        RAISE_APPLICATION_ERROR(-20003, 'DA_TRA va HUY khong the thay doi');
    END IF;
    IF :NEW.TrangThai = 'DA_TRA' THEN
        UPDATE Phong SET TrangThai = 'TRONG' WHERE MaPhong = :OLD.MaPhong;

        INSERT INTO LichSuPhong VALUES (
            'LS' || TO_CHAR(SYSDATE, 'SSSSS'),
            :OLD.MaPhong,
            :OLD.MaHD,
            :OLD.NgayNhan,
            :OLD.NgayTra,
            'Tra phong thanh cong'
        );
    END IF;
    IF :NEW.TrangThai = 'HUY' THEN
        UPDATE Phong SET TrangThai = 'TRONG' WHERE MaPhong = :OLD.MaPhong;
    END IF;
END trg_CapNhatTrangThaiHD;
/
-- Insert du lieu mau
INSERT INTO Phong VALUES ('P01', 'VIP', 'TRONG', 500000, 2000000, 2);
INSERT INTO KhachHang VALUES ('KH01', 'Nguyen Van A', '123456789', '0911111111', 'nva@gmail.com', 'Viet Nam');
COMMIT;

-- Insert HoaDon hop le
INSERT INTO HoaDon (MaHD, MaKH, MaPhong, NgayNhan, NgayTra, SoNguoi, TongTien, TrangThai)
VALUES ('HD01', 'KH01', 'P01',
    TO_DATE('25/04/2026', 'DD/MM/YYYY'),
    TO_DATE('28/04/2026', 'DD/MM/YYYY'),
    2, NULL, 'CHO_NHAN');
COMMIT;
SELECT * FROM HoaDon;
SELECT * FROM Phong;
-- TEST 
UPDATE HoaDon SET TrangThai = 'DANG_O' WHERE MaHD = 'HD01';
COMMIT;

UPDATE HoaDon SET TrangThai = 'DA_TRA' WHERE MaHD = 'HD01';
COMMIT;
SELECT MaPhong, TrangThai FROM Phong WHERE MaPhong = 'P01';
SELECT * FROM LichSuPhong;

UPDATE HoaDon SET TrangThai = 'DANG_O' WHERE MaHD = 'HD01';

-- C
CREATE OR REPLACE TRIGGER trg_SuaChiPhi
FOR INSERT OR UPDATE ON ChiPhiPhuThu
COMPOUND TRIGGER

    v_tongtien_goc NUMBER := 0;

    BEFORE STATEMENT IS
    BEGIN
        pkg_state2.g_row_count := 0;
    END BEFORE STATEMENT;

    BEFORE EACH ROW IS
    BEGIN
        -- dem so ban ghi bi thay doi
        pkg_state2.g_row_count := pkg_state2.g_row_count + 1;
        IF pkg_state2.g_row_count > 5 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Chi duoc INSERT/UPDATE toi da 5 chi phi');
        END IF;

        -- kiem tra SoTien hop le
        IF :NEW.SoTien <= 0 OR :NEW.SoTien >= 50000000 THEN
            RAISE_APPLICATION_ERROR(-20002, 'SoTien phai > 0 va < 50,000,000');
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        -- cap nhat lai TongTien HoaDon = SUM(ChiPhiPhuThu)
        UPDATE HoaDon H SET H.TongTien = (
            SELECT NVL(SUM(C.SoTien), 0) FROM ChiPhiPhuThu C WHERE C.MaHD = H.MaHD
        );
    END AFTER STATEMENT;

END trg_SuaChiPhi;
/

--TEST
-- TH1: Insert chi phi hop le
INSERT INTO ChiPhiPhuThu VALUES ('CP01', 'HD01', 'An sang', 200000, SYSDATE);
INSERT INTO ChiPhiPhuThu VALUES ('CP02', 'HD01', 'Giat ui', 100000, SYSDATE);
COMMIT;

-- Kiem tra TongTien HoaDon da cap nhat chua
SELECT MaHD, TongTien FROM HoaDon WHERE MaHD = 'HD01';

-- TH2: SoTien <= 0 bao loi
INSERT INTO ChiPhiPhuThu VALUES ('CP03', 'HD01', 'Test loi', -100000, SYSDATE);

-- TH3: SoTien >= 50,000,000 bao loi
INSERT INTO ChiPhiPhuThu VALUES ('CP04', 'HD01', 'Test loi', 60000000, SYSDATE);

-- D
-- Buoc 1: Tao sequence de sinh MaHD
CREATE SEQUENCE SEQ_HD START WITH 1 INCREMENT BY 1;

-- Buoc 2: Tao view vw_PhongTrong
CREATE OR REPLACE VIEW vw_PhongTrong AS
SELECT P.MaPhong, P.LoaiPhong, P.TrangThai,
       P.GiaTheoGio, P.GiaTheoNgay, P.SoNguoiToiDa
FROM Phong P
WHERE P.TrangThai = 'TRONG';

-- Buoc 3: Tao INSTEAD OF Trigger
CREATE OR REPLACE TRIGGER trg_vwPhongTrong_ins
INSTEAD OF INSERT ON vw_PhongTrong
FOR EACH ROW
DECLARE
    v_makh  VARCHAR2(10);
    v_mahd  VARCHAR2(10);
    v_dem   NUMBER := 0;
BEGIN
    SELECT MaKH INTO v_makh FROM KhachHang
    WHERE ROWNUM = 1;
    v_mahd := 'HD' || TO_CHAR(SEQ_HD.NEXTVAL, 'FM0000');

    SELECT COUNT(*) INTO v_dem FROM Phong WHERE MaPhong = :NEW.MaPhong;
    IF v_dem = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'MaPhong khong ton tai');
    END IF;
    INSERT INTO HoaDon (MaHD, MaKH, MaPhong, NgayNhan, NgayTra, SoNguoi, TongTien, TrangThai)
    VALUES (v_mahd, v_makh, :NEW.MaPhong,
        TO_DATE('25/04/2026', 'DD/MM/YYYY'),
        TO_DATE('28/04/2026', 'DD/MM/YYYY'),
        1, NULL, 'CHO_NHAN');
END trg_vwPhongTrong_ins;
/

--TEST
SELECT * FROM vw_PhongTrong;
-- TH1: Dat phong qua view -> tu dong tao MaHD
INSERT INTO vw_PhongTrong (MaPhong) VALUES ('P01');
COMMIT;
-- Kiem tra HoaDon da them chua
SELECT * FROM HoaDon;
-- Kiem tra TrangThai phong
SELECT MaPhong, TrangThai FROM Phong WHERE MaPhong = 'P01';