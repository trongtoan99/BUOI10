INSERT INTO SanPham VALUES ('SP01', 'HSX01', 'Samsung A54', 100, 'Den', 8000000, 'Cai', 'Dien thoai');
INSERT INTO NhanVien VALUES ('NV01', 'Nguyen Van A', 'Nam', 'HCM', '0911111111', 'nva@gmail.com', 'Kho');
INSERT INTO PNhap VALUES ('HDN01', TO_DATE('01/03/2025', 'DD/MM/YYYY'), 'NV01');
COMMIT;
-- PBT 1
-- A
CREATE OR REPLACE TRIGGER trg_Nhap
BEFORE INSERT ON Nhap
FOR EACH ROW
DECLARE
    v_dem     NUMBER := 0;
    v_soluong NUMBER := 0;
BEGIN
    -- kiem tra MaSP co ton tai khong
    SELECT COUNT(*) INTO v_dem FROM SanPham WHERE MaSP = :NEW.MaSP;
    IF v_dem = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'MaSP khong ton tai');
    END IF;

    -- kiem tra rang buoc du lieu
    IF :NEW.SoLuongN <= 0 OR :NEW.DonGiaN <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'SoLuongN va DonGiaN phai > 0');
    END IF;

    -- hop le -> cap nhat SoLuong
    UPDATE SanPham SET SoLuong = SoLuong + :NEW.SoLuongN
    WHERE MaSP = :NEW.MaSP;
END trg_Nhap;
/

--Test 
-- TH1: hop le SoLuong tang len
INSERT INTO Nhap VALUES ('HDN01', 'SP01', 50, 7000000);
COMMIT;
-- TH2: MaSP khong ton tai bao loi
INSERT INTO Nhap VALUES ('HDN01', 'SP99', 50, 7000000);
-- TH3: bao loi
INSERT INTO Nhap VALUES ('HDN01', 'SP01', -5, 7000000);

-- B
CREATE OR REPLACE TRIGGER trg_Xuat
BEFORE INSERT ON Xuat
FOR EACH ROW
DECLARE
    v_dem     NUMBER := 0;
    v_soluong NUMBER := 0;
BEGIN
    -- kiem tra MaSP co ton tai khong
    SELECT COUNT(*) INTO v_dem FROM SanPham WHERE MaSP = :NEW.MaSP;
    IF v_dem = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'MaSP khong ton tai');
    END IF;
    -- kiem tra SoLuongX <= SoLuong trong SanPham
    SELECT SoLuong INTO v_soluong FROM SanPham WHERE MaSP = :NEW.MaSP;
    IF :NEW.SoLuongX > v_soluong THEN
        RAISE_APPLICATION_ERROR(-20002, 'SoLuongX vuot qua so luong ton kho');
    END IF;
    -- hop le cap nhat SoLuong
    UPDATE SanPham SET SoLuong = SoLuong - :NEW.SoLuongX
    WHERE MaSP = :NEW.MaSP;
END trg_Xuat;
/

-- test
INSERT INTO PXuat VALUES ('HDX01', TO_DATE('05/03/2025', 'DD/MM/YYYY'), 'NV01');
COMMIT;
-- TH1: hop le SoLuong giam xuong
INSERT INTO Xuat VALUES ('HDX01', 'SP01', 10);
COMMIT;
-- TH2: MaSP khong ton taibao loi
INSERT INTO Xuat VALUES ('HDX01', 'SP99', 10);
-- TH3: SoLuongX vuot qua ton kho bao loi
INSERT INTO Xuat VALUES ('HDX01', 'SP01', 99999);

-- C 
CREATE OR REPLACE TRIGGER trg_XoaXuat
AFTER DELETE ON Xuat
FOR EACH ROW
BEGIN
    -- khi xoa phieu xuat -hoan tra soluong vao sanpham
    UPDATE SanPham SET SoLuong = SoLuong + :OLD.SoLuongX
    WHERE MaSP = :OLD.MaSP;
END trg_XoaXuat;
/

-- TEST
-- Kiem tra SoLuong truoc khi xoa
SELECT MaSP, SoLuong FROM SanPham WHERE MaSP = 'SP01';
-- TH1: Xoa phieu xuat số lượng tang len
DELETE FROM Xuat WHERE SoHDX = 'HDX01' AND MaSP = 'SP01';
COMMIT;
-- Kiem tra SoLuong sau khi xóa
SELECT MaSP, SoLuong FROM SanPham WHERE MaSP = 'SP01';

-- PHIEU BAI TAP 2
-- A 

-- Buoc 1: Tao package luu bien dem
CREATE OR REPLACE PACKAGE pkg_state AS
    g_row_count NUMBER := 0;
END pkg_state;
/

CREATE OR REPLACE TRIGGER trg_CapNhatXuat
FOR UPDATE ON Xuat
COMPOUND TRIGGER

    v_soluong NUMBER := 0;

    BEFORE STATEMENT IS
    BEGIN
        pkg_state.g_row_count := 0;
    END BEFORE STATEMENT;

    BEFORE EACH ROW IS
    BEGIN
        pkg_state.g_row_count := pkg_state.g_row_count + 1;
        IF pkg_state.g_row_count > 1 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Chi duoc cap nhat 1 ban ghi');
        END IF;
        IF :NEW.SoLuongX <> :OLD.SoLuongX THEN
            SELECT SoLuong INTO v_soluong FROM SanPham WHERE MaSP = :NEW.MaSP;
            IF v_soluong < (:NEW.SoLuongX - :OLD.SoLuongX) THEN
                RAISE_APPLICATION_ERROR(-20002, 'Khong du hang de xuat');
            END IF;
            UPDATE SanPham SET SoLuong = SoLuong - (:NEW.SoLuongX - :OLD.SoLuongX)
            WHERE MaSP = :NEW.MaSP;
        END IF;
    END BEFORE EACH ROW;

END trg_CapNhatXuat;
/

-- TEST
INSERT INTO PXuat VALUES ('HDX01', TO_DATE('05/03/2025', 'DD/MM/YYYY'), 'NV01');
INSERT INTO Xuat VALUES ('HDX01', 'SP01', 10);
COMMIT;
UPDATE Xuat SET SoLuongX = 20 WHERE SoHDX = 'HDX01' AND MaSP = 'SP01';
COMMIT;
UPDATE Xuat SET SoLuongX = 5;
UPDATE Xuat SET SoLuongX = 99999 WHERE SoHDX = 'HDX01' AND MaSP = 'SP01';

-- B 
-- Tao package neu chua co
CREATE OR REPLACE PACKAGE pkg_state AS
    g_row_count NUMBER := 0;
END pkg_state;
/

-- Tao Compound Trigger
CREATE OR REPLACE TRIGGER trg_CapNhatNhap
FOR UPDATE ON Nhap
COMPOUND TRIGGER
    v_soluong NUMBER := 0;
    BEFORE STATEMENT IS
    BEGIN
        pkg_state.g_row_count := 0;
    END BEFORE STATEMENT;

    BEFORE EACH ROW IS
    BEGIN
        pkg_state.g_row_count := pkg_state.g_row_count + 1;
        IF pkg_state.g_row_count > 1 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Chi duoc cap nhat 1 ban ghi');
        END IF;
        IF :NEW.SoLuongN <> :OLD.SoLuongN THEN
            UPDATE SanPham SET SoLuong = SoLuong + (:NEW.SoLuongN - :OLD.SoLuongN)
            WHERE MaSP = :NEW.MaSP;
        END IF;
    END BEFORE EACH ROW;

END trg_CapNhatNhap;
/

-- test 

-- Them du lieu mau
INSERT INTO PNhap VALUES ('HDN01', TO_DATE('01/03/2025', 'DD/MM/YYYY'), 'NV01');
INSERT INTO Nhap VALUES ('HDN01', 'SP01', 50, 7000000);
COMMIT;
SELECT MaSP, SoLuong FROM SanPham WHERE MaSP = 'SP01';
-- TH1: Cap nhat 1 ban ghi hop le số lượng thay doi
UPDATE Nhap SET SoLuongN = 80 WHERE SoHDN = 'HDN01' AND MaSP = 'SP01';
COMMIT;
-- Kiem tra số lượng sau khi update
SELECT MaSP, SoLuong FROM SanPham WHERE MaSP = 'SP01';

INSERT INTO SanPham VALUES ('SP02', 'HSX01', 'Samsung A34', 50, 'Trang', 6000000, 'Cai', 'Dien thoai');
INSERT INTO Nhap VALUES ('HDN01', 'SP02', 30, 6000000);
COMMIT;
-- Them 1 san pham va 1 ban ghi Nhap
INSERT INTO SanPham VALUES ('SP02', 'HSX01', 'Samsung A34', 50, 'Trang', 6000000, 'Cai', 'Dien thoai');
INSERT INTO Nhap VALUES ('HDN01', 'SP02', 30, 6000000);
COMMIT;
UPDATE Nhap SET SoLuongN = 10;

--C 
CREATE OR REPLACE TRIGGER trg_XoaNhap
AFTER DELETE ON Nhap
FOR EACH ROW
BEGIN
    UPDATE SanPham SET SoLuong = SoLuong - :OLD.SoLuongN
    WHERE MaSP = :OLD.MaSP;
END trg_XoaNhap;
/

-- test 
-- Kiem tra SoLuong truoc khi xoa
SELECT MaSP, SoLuong FROM SanPham WHERE MaSP = 'SP01';
-- TH1: Xoa phieu nhap số lượng giam xuong
DELETE FROM Nhap WHERE SoHDN = 'HDN01' AND MaSP = 'SP01';
COMMIT;
-- Kiem tra số lượng sau khi xoa
SELECT MaSP, SoLuong FROM SanPham WHERE MaSP = 'SP01';