-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: 30 أبريل 2026 الساعة 00:25
-- إصدار الخادم: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `darbak_db`
--

-- --------------------------------------------------------

--
-- بنية الجدول `bids`
--

CREATE TABLE `bids` (
  `id` int(11) NOT NULL,
  `shipment_id` int(11) NOT NULL,
  `driver_id` int(11) NOT NULL,
  `bid_amount` decimal(10,2) NOT NULL,
  `estimated_days` int(11) NOT NULL,
  `bid_status` enum('pending','accepted','rejected') DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `bids`
--

INSERT INTO `bids` (`id`, `shipment_id`, `driver_id`, `bid_amount`, `estimated_days`, `bid_status`, `created_at`) VALUES
(1, 1, 2, 1400.00, 3, 'pending', '2026-03-31 20:42:25'),
(2, 8, 2, 4500.00, 5, 'pending', '2026-04-14 17:25:10'),
(3, 8, 8, 4200.00, 5, 'pending', '2026-04-15 15:36:01'),
(4, 9, 10, 2800.00, 5, 'accepted', '2026-04-15 18:04:51'),
(5, 10, 10, 2300.00, 5, 'pending', '2026-04-16 08:27:35'),
(6, 11, 10, 4400.00, 5, 'accepted', '2026-04-20 19:29:57'),
(7, 12, 10, 2300.00, 5, 'accepted', '2026-04-21 21:20:55'),
(8, 13, 10, 4500.00, 5, 'accepted', '2026-04-21 21:50:35'),
(9, 15, 16, 1100.00, 5, 'accepted', '2026-04-29 19:16:11'),
(10, 16, 16, 1000.00, 5, 'accepted', '2026-04-29 21:39:56');

-- --------------------------------------------------------

--
-- بنية الجدول `compliance_documents`
--

CREATE TABLE `compliance_documents` (
  `document_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `document_type` enum('driver_license','vehicle_insurance','commercial_registration','tax_certificate','safety_certificate') NOT NULL,
  `document_url` varchar(255) NOT NULL,
  `issue_date` date DEFAULT NULL,
  `expiry_date` date NOT NULL,
  `is_verified` tinyint(1) DEFAULT 0,
  `verified_by` int(11) DEFAULT NULL,
  `verified_at` timestamp NULL DEFAULT NULL,
  `verification_notes` text DEFAULT NULL,
  `uploaded_at` timestamp NULL DEFAULT current_timestamp(),
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- إرجاع أو استيراد بيانات الجدول `compliance_documents`
--

INSERT INTO `compliance_documents` (`document_id`, `user_id`, `document_type`, `document_url`, `issue_date`, `expiry_date`, `is_verified`, `verified_by`, `verified_at`, `verification_notes`, `uploaded_at`, `created_at`, `updated_at`) VALUES
(1, 18, 'commercial_registration', 'commercial_docs/1777499336474-IMG_20260423_140242.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-04-29 21:48:56', '2026-04-29 21:48:56', '2026-04-29 21:48:56'),
(2, 19, 'commercial_registration', 'commercial_docs/1777500650306-35.pdf', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-04-29 22:10:50', '2026-04-29 22:10:50', '2026-04-29 22:10:50'),
(3, 20, 'commercial_registration', 'commercial_docs/1777500934038-IMG_20260423_140242.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-04-29 22:15:34', '2026-04-29 22:15:34', '2026-04-29 22:15:34');

-- --------------------------------------------------------

--
-- بنية الجدول `messages`
--

CREATE TABLE `messages` (
  `id` int(11) NOT NULL,
  `shipment_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `receiver_id` int(11) NOT NULL,
  `message` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `messages`
--

INSERT INTO `messages` (`id`, `shipment_id`, `sender_id`, `receiver_id`, `message`, `created_at`) VALUES
(1, 15, 15, 16, 'تاليي', '2026-04-29 19:34:42'),
(2, 15, 15, 16, 'sdfdsfdsf', '2026-04-29 20:45:59');

-- --------------------------------------------------------

--
-- بنية الجدول `notifications`
--

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- بنية الجدول `ratings`
--

CREATE TABLE `ratings` (
  `id` int(11) NOT NULL,
  `shipment_id` int(11) NOT NULL,
  `rater_id` int(11) NOT NULL,
  `rated_id` int(11) NOT NULL,
  `stars` int(1) NOT NULL CHECK (`stars` between 1 and 5),
  `comment` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- بنية الجدول `shipments`
--

CREATE TABLE `shipments` (
  `id` int(11) NOT NULL,
  `shipper_id` int(11) NOT NULL,
  `driver_id` int(11) DEFAULT NULL,
  `weight_kg` decimal(10,2) NOT NULL,
  `cargo_description` text DEFAULT NULL,
  `pickup_address` varchar(255) NOT NULL,
  `pickup_lat` decimal(10,8) DEFAULT NULL,
  `pickup_lng` decimal(11,8) DEFAULT NULL,
  `dropoff_address` varchar(255) NOT NULL,
  `dropoff_lat` decimal(10,8) DEFAULT NULL,
  `dropoff_lng` decimal(11,8) DEFAULT NULL,
  `base_price` decimal(10,2) NOT NULL,
  `final_price` decimal(10,2) DEFAULT NULL,
  `status` enum('pending','bidding','assigned','at_pickup','en_route','at_dropoff','delivered','cancelled') DEFAULT 'pending',
  `expected_delivery_date` datetime NOT NULL,
  `actual_delivery_date` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `period` enum('morning','evening') DEFAULT NULL,
  `special_instructions` text DEFAULT NULL,
  `auction_duration_hours` int(11) DEFAULT 24,
  `auction_end_time` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `shipments`
--

INSERT INTO `shipments` (`id`, `shipper_id`, `driver_id`, `weight_kg`, `cargo_description`, `pickup_address`, `pickup_lat`, `pickup_lng`, `dropoff_address`, `dropoff_lat`, `dropoff_lng`, `base_price`, `final_price`, `status`, `expected_delivery_date`, `actual_delivery_date`, `created_at`, `period`, `special_instructions`, `auction_duration_hours`, `auction_end_time`) VALUES
(1, 4, NULL, 8.50, '????? ????', '??????', NULL, NULL, '???', NULL, NULL, 1400.00, NULL, 'bidding', '2025-05-01 00:00:00', NULL, '2026-03-31 20:34:30', NULL, NULL, 24, NULL),
(2, 1, NULL, 2.00, 'مفروشات', 'مكة', NULL, NULL, 'جدة', NULL, NULL, 1000.00, NULL, 'bidding', '2026-04-10 09:20:00', NULL, '2026-04-09 07:14:06', NULL, NULL, 24, NULL),
(3, 1, NULL, 2.00, 'مفروشات', 'مكة', NULL, NULL, 'جدة', NULL, NULL, 1000.00, NULL, 'bidding', '2026-04-10 09:20:00', NULL, '2026-04-09 07:14:15', NULL, NULL, 24, NULL),
(4, 1, NULL, 2.00, 'مفروشات', 'مكة', NULL, NULL, 'جدة', NULL, NULL, 1000.00, NULL, 'bidding', '2026-04-10 09:20:00', NULL, '2026-04-09 07:14:22', NULL, NULL, 24, NULL),
(5, 1, NULL, 2.00, 'مواد بناء', 'الرياض', NULL, NULL, 'جدة', NULL, NULL, 4200.00, NULL, 'bidding', '2026-04-11 08:00:00', NULL, '2026-04-09 07:56:17', NULL, NULL, 24, NULL),
(6, 1, NULL, 0.40, 'معدات', 'سش', NULL, NULL, 'طنطا', NULL, NULL, 650.00, NULL, 'bidding', '2026-04-12 12:00:00', NULL, '2026-04-09 08:15:00', NULL, NULL, 24, NULL),
(7, 1, NULL, 2.00, 'مفروشات', 'الرياض', NULL, NULL, 'مكة', NULL, NULL, 4500.00, NULL, 'bidding', '2026-04-13 15:10:00', NULL, '2026-04-09 10:09:39', NULL, NULL, 24, NULL),
(8, 1, NULL, 2.00, 'مفروشات', 'الرياض', NULL, NULL, 'مكة', NULL, NULL, 4500.00, NULL, 'bidding', '2026-04-13 15:10:00', NULL, '2026-04-09 10:10:32', NULL, NULL, 24, NULL),
(9, 9, 10, 2.30, 'ادوات بناء', 'مكة', NULL, NULL, 'الرياض', NULL, NULL, 3000.00, NULL, 'en_route', '2026-04-28 00:00:00', NULL, '2026-04-15 18:01:42', 'morning', NULL, 24, NULL),
(10, 9, NULL, 1.60, 'معدات', 'الدمام', NULL, NULL, 'الرياض', NULL, NULL, 2600.00, NULL, 'bidding', '2026-04-23 00:00:00', NULL, '2026-04-15 19:59:56', 'evening', NULL, 24, NULL),
(11, 9, 10, 3.40, 'حديد', 'مكة', NULL, NULL, 'الرياض', NULL, NULL, 4600.00, NULL, 'at_dropoff', '2026-04-30 00:00:00', NULL, '2026-04-20 19:28:54', 'morning', 'يجب ن يكون في الشاحنة حواجز لتجنب تحرك الحديد اثناء النقل', 24, NULL),
(12, 9, 10, 0.80, 'اواني منزلية', 'الرياض', NULL, NULL, 'الدمام', NULL, NULL, 2300.00, NULL, 'at_dropoff', '2026-04-24 00:00:00', NULL, '2026-04-21 21:20:15', 'evening', 'الرجاء التعامل معها بحذر شديد', 24, NULL),
(13, 9, 10, 6.50, 'سيارات', 'الرياض', 24.74500655, 46.68339261, 'الاحساء', 24.66431361, 46.67647710, 4500.00, NULL, 'at_dropoff', '2026-04-29 00:00:00', NULL, '2026-04-21 21:50:03', 'evening', 'يجب ان تكون الشاحنة تسمح بحمل السيارات وتكون دورين', 24, NULL),
(14, 9, NULL, 4.00, '4', 'k', 24.73418221, 46.67152345, 'm', 24.71404554, 46.67530000, 4.00, NULL, 'bidding', '2026-04-25 00:00:00', NULL, '2026-04-21 23:13:22', 'morning', '4', 24, NULL),
(15, 15, 16, 23.00, 'حديد', 'الرياض', 24.71360000, 46.67530000, 'جدة', 24.70667850, 46.67283160, 1200.00, NULL, 'delivered', '2026-04-30 00:00:00', '2026-04-30 00:36:06', '2026-04-29 19:13:37', 'evening', NULL, 24, '2026-04-30 22:13:37'),
(16, 15, 16, 12.00, '212', 'اااتاا', 24.71360000, 46.67530000, 'للبل', 24.71360000, 46.67530000, 1233.00, NULL, 'delivered', '2026-05-28 00:00:00', '2026-04-30 00:40:56', '2026-04-29 21:39:24', 'evening', NULL, 12, '2026-04-30 12:39:24');

-- --------------------------------------------------------

--
-- بنية الجدول `shipment_status_history`
--

CREATE TABLE `shipment_status_history` (
  `id` int(11) NOT NULL,
  `shipment_id` int(11) NOT NULL,
  `status` enum('assigned','at_pickup','en_route','at_dropoff','delivered') NOT NULL,
  `location_lat` decimal(10,8) DEFAULT NULL,
  `location_lng` decimal(11,8) DEFAULT NULL,
  `photo_path` varchar(500) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `shipment_status_history`
--

INSERT INTO `shipment_status_history` (`id`, `shipment_id`, `status`, `location_lat`, `location_lng`, `photo_path`, `updated_at`) VALUES
(1, 11, 'at_pickup', NULL, NULL, NULL, '2026-04-20 20:11:58'),
(2, 11, 'en_route', NULL, NULL, NULL, '2026-04-20 20:12:20'),
(3, 11, 'at_dropoff', NULL, NULL, NULL, '2026-04-20 20:12:35'),
(4, 9, 'at_pickup', NULL, NULL, NULL, '2026-04-21 21:16:03'),
(5, 12, 'at_pickup', NULL, NULL, NULL, '2026-04-21 21:22:21'),
(6, 12, 'en_route', NULL, NULL, NULL, '2026-04-21 21:32:13'),
(7, 12, 'at_dropoff', NULL, NULL, NULL, '2026-04-21 21:32:29'),
(8, 13, 'at_pickup', NULL, NULL, NULL, '2026-04-22 20:53:34'),
(9, 13, 'en_route', NULL, NULL, NULL, '2026-04-22 20:54:23'),
(10, 13, 'at_dropoff', NULL, NULL, NULL, '2026-04-22 20:54:34'),
(11, 9, 'en_route', NULL, NULL, NULL, '2026-04-23 11:31:18'),
(12, 15, 'at_pickup', NULL, NULL, NULL, '2026-04-29 19:17:28'),
(13, 15, 'en_route', NULL, NULL, NULL, '2026-04-29 19:37:20'),
(14, 15, 'at_dropoff', NULL, NULL, NULL, '2026-04-29 19:37:24'),
(15, 15, 'delivered', NULL, NULL, 'epod/1777498566582-IMG_20260423_140242.jpg', '2026-04-29 21:36:06'),
(16, 16, 'at_pickup', NULL, NULL, NULL, '2026-04-29 21:40:36'),
(17, 16, 'en_route', NULL, NULL, NULL, '2026-04-29 21:40:41'),
(18, 16, 'at_dropoff', NULL, NULL, NULL, '2026-04-29 21:40:45'),
(19, 16, 'delivered', NULL, NULL, 'epod/1777498856394-IMG_20260423_140242.jpg', '2026-04-29 21:40:56');

-- --------------------------------------------------------

--
-- بنية الجدول `trucks`
--

CREATE TABLE `trucks` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `plate_number` varchar(20) NOT NULL,
  `isthimara_no` text DEFAULT NULL,
  `truck_type` enum('دباب نقل','وانيت','دينا','لوري','سطحة','تريلا جوانب','تريلا ستارة','برادة','صهريج','قلاب','مبرد') NOT NULL,
  `capacity_kg` decimal(10,2) NOT NULL,
  `manufacturing_year` int(4) NOT NULL,
  `insurance_expiry_date` date NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 0,
  `verification_status` enum('pending','verified','rejected') DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `trucks`
--

INSERT INTO `trucks` (`id`, `user_id`, `plate_number`, `isthimara_no`, `truck_type`, `capacity_kg`, `manufacturing_year`, `insurance_expiry_date`, `is_active`, `verification_status`, `created_at`) VALUES
(1, 14, '45845', '593a9b245f0ec29e5481e7f959347a44', '', 0.00, 2026, '2027-04-28', 1, 'pending', '2026-04-29 15:03:22'),
(2, 16, 'ص ر ي ١٢٣٤', '28786b32f5af63af0bc51c12c44a62e3', '', 0.00, 2026, '2027-04-28', 1, 'pending', '2026-04-29 19:15:32'),
(3, 17, '23123213', 'f6ae4cccdb8b3787188ec10b01a5388d', '', 0.00, 2026, '2027-04-28', 1, 'pending', '2026-04-29 19:41:43'),
(4, 16, '13123', 'b536a5393373d72cac9b91d1398064bc', 'دينا', 0.00, 2026, '2027-04-29', 0, 'pending', '2026-04-29 21:41:52');

-- --------------------------------------------------------

--
-- بنية الجدول `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `full_name` varchar(150) NOT NULL,
  `email` varchar(150) DEFAULT NULL,
  `phone` varchar(15) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('driver','shipper','admin') NOT NULL DEFAULT 'driver',
  `license_no` text DEFAULT NULL,
  `commercial_no` text DEFAULT NULL,
  `document_path` varchar(255) DEFAULT NULL,
  `verification_status` enum('pending','verified','rejected') DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `issue_date` date DEFAULT NULL,
  `expiry_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `users`
--

INSERT INTO `users` (`id`, `full_name`, `email`, `phone`, `password`, `role`, `license_no`, `commercial_no`, `document_path`, `verification_status`, `created_at`, `issue_date`, `expiry_date`) VALUES
(1, 'faris', NULL, '05', '$2a$10$DQ1iF3idtFCk6adc30aA3.iXYmcLeRrcenTbfr3w0cr7adaGLPuKe', 'shipper', NULL, '12001200', NULL, 'pending', '2026-03-31 19:47:48', NULL, NULL),
(2, 'احمد', NULL, '054', '$2a$10$DX723dUr3xrljzjYbHSiD.ZlVLYZ8omNbZVIPkvBohLHnZFH3tqZy', 'driver', '12345678', NULL, NULL, 'pending', '2026-03-31 20:03:42', NULL, NULL),
(3, 'Test Shipper', NULL, '0551000000', '$2a$10$qvvKaYHpH1jGwPMF3exaWOXduBdK8rTBWPB/g3tGbZno.KxmcDAeq', 'shipper', NULL, '56001234', NULL, 'pending', '2026-03-31 20:31:25', NULL, NULL),
(4, 'Test Shipper2', 'testshipper2@darbak.com', '0551000001', '$2a$10$HjZGe1y9eL751TnlbXdJHe6u8pCWXRQ4jatCBc17cRomQQ5mnIp3G', 'shipper', NULL, '56001235', NULL, 'pending', '2026-03-31 20:33:57', NULL, NULL),
(5, 'فارس محمد', 'db@gmail.com', '051', '$2a$10$1IHxHtF6KPYUJ0rIBmJ6reRXIzrQkHWELR4re6/xvc2TnwzROSIwS', 'driver', '145', NULL, NULL, 'pending', '2026-03-31 20:41:28', NULL, NULL),
(6, 'وليد', 'wly@gmai.com', '057', '$2a$10$H/GRyyiE29GSOorZqn0cI.lYWKbSO.dZuZOjDLJJIVpx88AOzKuLm', 'driver', '555', NULL, NULL, 'pending', '2026-04-14 18:58:41', '2005-07-04', '2030-04-14'),
(7, 'تشفير', 'xr@gmail.com', '059', '$2a$10$dNayMRhBwqfdRORV1aB.2e.94fjfgrRUjfu1y8lm9Vm4azgMvSpoG', 'driver', '1128677570', NULL, NULL, 'pending', '2026-04-15 14:42:49', '2021-04-15', '2027-04-15'),
(8, 'اختبار تشفير', 'hdh@gmail.com', '053', '$2a$10$qqdboI4hYIVzX/xWajmx.eybuls9zxLzHDlbUcpbOqu5IPGeLHSzC', 'driver', '6e47adf7ebc466cbebe0f7a107f57cbc', NULL, NULL, 'pending', '2026-04-15 15:18:10', '2020-04-15', '2030-04-15'),
(9, 'sz', 'bb@bb.com', '011', '$2a$10$bszVKXQIjurk69vqF6AUh.t1kcMCH180b1PXBhz/nMEEqHEvQ8CH6', 'shipper', NULL, '98ccc0e11df969d1816b6fa2c7085219', NULL, 'pending', '2026-04-15 17:59:17', NULL, NULL),
(10, 'SSSF', 'SSFS@GMAIL.COM', '022', '$2a$10$0TJR84mrsnU61rngLR0SPeleVvxr.wCZxYN7J3jpDKUC8TUqNsaLK', 'driver', 'ce048382a0c2d863363315742d21dac1', NULL, NULL, 'pending', '2026-04-15 18:04:13', '2022-04-15', '2026-04-30'),
(11, 'حمد', 'svcwsd@gmail.com', '044', '$2a$10$qCb0SIWV.k9055au4urw5uuPYRNeUibsw7DwGzC1c5OCWAArm7Zge', 'driver', 'be3bd62e3560be68b4590f03eba38eb2', NULL, NULL, 'pending', '2026-04-29 14:34:47', '2030-04-29', '2031-04-29'),
(12, 'حمد', 'svcws445d@gmail.com', '44', '$2a$10$8zi5jAabZyVT2bTErhexluNBU6G2FE/e0EzI5Qcm4/Qy8k0P/KBU2', 'driver', 'be3bd62e3560be68b4590f03eba38eb2', NULL, NULL, 'pending', '2026-04-29 14:35:59', '2030-04-29', '2031-04-29'),
(13, 'حمد', 'ssdsd@gmail.com', '066', '$2a$10$8sqYt62fnwmzmLm6DB3FL.T46nj5m0JDdCNqNxD5MNi8P7aNkRdJi', 'driver', 'd91b6b17e711bd49f6f793fe945b2b3e', NULL, NULL, 'pending', '2026-04-29 14:47:09', '2026-04-02', '2033-04-29'),
(14, 'داود', 'xsdx@gmail.com', '099', '$2a$10$VnC2.zBVAfYS48CyHcSSE.k97t2a89jLN46ANwRwPJ7jK1.FP2PRG', 'driver', '1c266473bec8cc370b5530fff6e9f205', NULL, NULL, 'pending', '2026-04-29 15:03:22', '2024-04-29', '2034-04-19'),
(15, 'abdulrahim', 'abdo@gmail.com', '0540', '$2a$10$PC2K1uo9kLptltGK/hXt1uw.EFZzVS9Y/rCy1pl1VSJc7x/CBDLoO', 'shipper', NULL, '84ecd6564f979a5e6862ceb5b742e2b3', NULL, 'pending', '2026-04-29 19:10:29', NULL, NULL),
(16, 'abdulrahimdr', 'abdoe@gmail.com', '05407', '$2a$10$TrRyWMq0fITPLHn/1UQwVeVKp7KMm5a.AWu/asaqXa.wD0ld7M0Se', 'driver', 'fccdea1bc58204165805663e1560468f', NULL, NULL, 'pending', '2026-04-29 19:15:32', '2026-04-14', '2026-04-30'),
(17, 'asdsad', 'asdsad@gmail.com', '1111', '$2a$10$F6ZepNTU/0YIUwDYJ1bn/eZt5xEBdOb4v9Q54gCv2KXaS/hMKRriy', 'admin', '68be90c0c652c39fa4351d8fdc99dac7', NULL, NULL, 'pending', '2026-04-29 19:41:43', '2026-04-20', '2026-04-30'),
(18, 'غعلا', 'easfdsdf@gmail.com', '04678', '$2a$10$nAuwP3Ta9FYAStVryYvN5u3SLBR90b1j.yirr3k5SxOA/J3Xk4K8W', 'shipper', NULL, 'd7cbd6ee1536f23934fb81198e472579feea954e582980d5f51cac1f60acc474', 'commercial_docs/1777499336474-IMG_20260423_140242.jpg', 'pending', '2026-04-29 21:48:56', NULL, '2099-12-31'),
(19, 'sfsdfsdsdfds', 'dsfdsf@gmail.com', '234324', '$2a$10$CTZDx0MWKNjcHReb4Nyj3.ZnzXiYxBBudXG3mqad4uecihKzTNH9y', 'shipper', NULL, '7cde99609fbe10782900930716578a23', 'commercial_docs/1777500650306-35.pdf', 'pending', '2026-04-29 22:10:50', NULL, '2099-12-31'),
(20, 'sdfsd', 'sdfsdf@gmail.com', '0987', '$2a$10$cFKgQEpPWqvZew3uS3vrS.VvY5Lw63D1/iUB18HG/UckebuPJXqI.', 'shipper', NULL, 'c4b8de3da4d651713749e8e3ef73e082', 'commercial_docs/1777500934038-IMG_20260423_140242.jpg', 'pending', '2026-04-29 22:15:34', NULL, '2099-12-31');

-- --------------------------------------------------------

--
-- بنية الجدول `wallets`
--

CREATE TABLE `wallets` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `current_balance` decimal(15,2) DEFAULT 0.00,
  `total_earned` decimal(15,2) DEFAULT 0.00,
  `last_transaction` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `wallets`
--

INSERT INTO `wallets` (`id`, `user_id`, `current_balance`, `total_earned`, `last_transaction`) VALUES
(1, 1, 0.00, 0.00, '2026-03-31 19:47:48'),
(2, 2, 0.00, 0.00, '2026-03-31 20:03:42'),
(3, 3, 0.00, 0.00, '2026-03-31 20:31:25'),
(4, 4, 0.00, 0.00, '2026-03-31 20:33:57'),
(5, 5, 0.00, 0.00, '2026-03-31 20:41:28'),
(6, 6, 0.00, 0.00, '2026-04-14 18:58:41'),
(7, 7, 0.00, 0.00, '2026-04-15 14:42:49'),
(8, 8, 0.00, 0.00, '2026-04-15 15:18:10'),
(9, 9, 0.00, 0.00, '2026-04-15 17:59:17'),
(10, 10, 0.00, 0.00, '2026-04-15 18:04:13'),
(11, 11, 0.00, 0.00, '2026-04-29 14:34:47'),
(12, 12, 0.00, 0.00, '2026-04-29 14:35:59'),
(13, 13, 0.00, 0.00, '2026-04-29 14:47:09'),
(14, 14, 0.00, 0.00, '2026-04-29 15:03:22'),
(15, 15, 0.00, 0.00, '2026-04-29 19:10:29'),
(16, 16, 0.00, 0.00, '2026-04-29 19:15:32'),
(17, 17, 0.00, 0.00, '2026-04-29 19:41:43'),
(18, 18, 0.00, 0.00, '2026-04-29 21:48:56'),
(19, 19, 0.00, 0.00, '2026-04-29 22:10:50'),
(20, 20, 0.00, 0.00, '2026-04-29 22:15:34');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `bids`
--
ALTER TABLE `bids`
  ADD PRIMARY KEY (`id`),
  ADD KEY `driver_id` (`driver_id`),
  ADD KEY `idx_bids_shipment` (`shipment_id`);

--
-- Indexes for table `compliance_documents`
--
ALTER TABLE `compliance_documents`
  ADD PRIMARY KEY (`document_id`),
  ADD KEY `verified_by` (`verified_by`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_document_type` (`document_type`),
  ADD KEY `idx_expiry_date` (`expiry_date`),
  ADD KEY `idx_is_verified` (`is_verified`),
  ADD KEY `idx_compliance_status` (`user_id`,`expiry_date`,`is_verified`);

--
-- Indexes for table `messages`
--
ALTER TABLE `messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `shipment_id` (`shipment_id`),
  ADD KEY `sender_id` (`sender_id`),
  ADD KEY `receiver_id` (`receiver_id`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `ratings`
--
ALTER TABLE `ratings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `shipment_id` (`shipment_id`),
  ADD KEY `rater_id` (`rater_id`),
  ADD KEY `rated_id` (`rated_id`);

--
-- Indexes for table `shipments`
--
ALTER TABLE `shipments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `shipper_id` (`shipper_id`),
  ADD KEY `driver_id` (`driver_id`);

--
-- Indexes for table `shipment_status_history`
--
ALTER TABLE `shipment_status_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_shipment_updated` (`shipment_id`,`updated_at`);

--
-- Indexes for table `trucks`
--
ALTER TABLE `trucks`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `plate_number` (`plate_number`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `phone` (`phone`),
  ADD KEY `phone_2` (`phone`);

--
-- Indexes for table `wallets`
--
ALTER TABLE `wallets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `bids`
--
ALTER TABLE `bids`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `compliance_documents`
--
ALTER TABLE `compliance_documents`
  MODIFY `document_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `messages`
--
ALTER TABLE `messages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ratings`
--
ALTER TABLE `ratings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `shipments`
--
ALTER TABLE `shipments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT for table `shipment_status_history`
--
ALTER TABLE `shipment_status_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `trucks`
--
ALTER TABLE `trucks`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `wallets`
--
ALTER TABLE `wallets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- قيود الجداول المُلقاة.
--

--
-- قيود الجداول `bids`
--
ALTER TABLE `bids`
  ADD CONSTRAINT `bids_ibfk_1` FOREIGN KEY (`shipment_id`) REFERENCES `shipments` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `bids_ibfk_2` FOREIGN KEY (`driver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- قيود الجداول `compliance_documents`
--
ALTER TABLE `compliance_documents`
  ADD CONSTRAINT `compliance_documents_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `compliance_documents_ibfk_2` FOREIGN KEY (`verified_by`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- قيود الجداول `messages`
--
ALTER TABLE `messages`
  ADD CONSTRAINT `messages_ibfk_1` FOREIGN KEY (`shipment_id`) REFERENCES `shipments` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_ibfk_2` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_ibfk_3` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- قيود الجداول `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- قيود الجداول `ratings`
--
ALTER TABLE `ratings`
  ADD CONSTRAINT `ratings_ibfk_1` FOREIGN KEY (`shipment_id`) REFERENCES `shipments` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ratings_ibfk_2` FOREIGN KEY (`rater_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ratings_ibfk_3` FOREIGN KEY (`rated_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- قيود الجداول `shipments`
--
ALTER TABLE `shipments`
  ADD CONSTRAINT `shipments_ibfk_1` FOREIGN KEY (`shipper_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `shipments_ibfk_2` FOREIGN KEY (`driver_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- قيود الجداول `shipment_status_history`
--
ALTER TABLE `shipment_status_history`
  ADD CONSTRAINT `shipment_status_history_ibfk_1` FOREIGN KEY (`shipment_id`) REFERENCES `shipments` (`id`) ON DELETE CASCADE;

--
-- قيود الجداول `trucks`
--
ALTER TABLE `trucks`
  ADD CONSTRAINT `trucks_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- قيود الجداول `wallets`
--
ALTER TABLE `wallets`
  ADD CONSTRAINT `wallets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
