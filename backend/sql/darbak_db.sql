-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: 21 مايو 2026 الساعة 10:51
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
-- بنية الجدول `admin_notification_reads`
--

CREATE TABLE `admin_notification_reads` (
  `notification_key` varchar(191) NOT NULL,
  `read_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- إرجاع أو استيراد بيانات الجدول `admin_notification_reads`
--

INSERT INTO `admin_notification_reads` (`notification_key`, `read_at`) VALUES
('bid_1', '2026-05-02 23:12:13'),
('bid_17', '2026-05-02 23:12:13'),
('bid_18', '2026-05-02 23:12:13'),
('bid_19', '2026-05-02 23:12:13'),
('bid_2', '2026-05-02 23:12:13'),
('bid_3', '2026-05-02 23:12:13'),
('bid_5', '2026-05-02 23:12:13'),
('bidstat_10_accepted', '2026-05-02 23:12:13'),
('bidstat_11_accepted', '2026-05-02 23:12:13'),
('bidstat_12_accepted', '2026-05-02 23:12:13'),
('bidstat_13_accepted', '2026-05-02 23:12:13'),
('bidstat_14_accepted', '2026-05-02 23:12:13'),
('bidstat_15_accepted', '2026-05-02 23:12:13'),
('bidstat_16_accepted', '2026-05-02 23:12:13'),
('bidstat_4_accepted', '2026-05-02 23:12:13'),
('bidstat_6_accepted', '2026-05-02 23:12:13'),
('bidstat_7_accepted', '2026-05-02 23:12:13'),
('bidstat_8_accepted', '2026-05-02 23:12:13'),
('bidstat_9_accepted', '2026-05-02 23:12:13'),
('doc_1', '2026-05-02 23:12:13'),
('doc_10', '2026-05-02 23:12:13'),
('doc_11', '2026-05-02 23:12:13'),
('doc_12', '2026-05-02 23:37:48'),
('doc_13', '2026-05-02 23:37:48'),
('doc_14', '2026-05-02 23:58:18'),
('doc_15', '2026-05-04 01:33:31'),
('doc_16', '2026-05-04 01:33:31'),
('doc_2', '2026-05-02 23:12:13'),
('doc_3', '2026-05-02 23:12:13'),
('doc_4', '2026-05-02 23:12:13'),
('doc_5', '2026-05-02 23:12:13'),
('doc_6', '2026-05-02 23:12:13'),
('doc_7', '2026-05-02 23:12:13'),
('doc_8', '2026-05-02 23:12:13'),
('doc_9', '2026-05-02 23:12:13'),
('rating_1', '2026-05-02 23:12:13'),
('rating_2', '2026-05-02 23:12:13'),
('rating_3', '2026-05-02 23:12:13'),
('rating_4', '2026-05-02 23:12:13'),
('reg_10', '2026-05-02 23:12:13'),
('reg_11', '2026-05-02 23:12:13'),
('reg_12', '2026-05-02 23:12:13'),
('reg_13', '2026-05-02 23:12:13'),
('reg_14', '2026-05-02 23:12:13'),
('reg_15', '2026-05-02 23:12:13'),
('reg_16', '2026-05-02 23:12:13'),
('reg_18', '2026-05-02 23:12:13'),
('reg_19', '2026-05-02 23:12:13'),
('reg_2', '2026-05-02 23:12:13'),
('reg_20', '2026-05-02 23:12:13'),
('reg_21', '2026-05-02 23:12:13'),
('reg_22', '2026-05-02 23:12:13'),
('reg_23', '2026-05-02 23:12:13'),
('reg_24', '2026-05-02 23:12:13'),
('reg_25', '2026-05-02 23:12:13'),
('reg_26', '2026-05-02 23:12:13'),
('reg_27', '2026-05-02 23:12:13'),
('reg_28', '2026-05-02 23:12:13'),
('reg_29', '2026-05-02 23:12:13'),
('reg_3', '2026-05-02 23:12:13'),
('reg_30', '2026-05-02 23:12:13'),
('reg_31', '2026-05-02 23:12:13'),
('reg_32', '2026-05-02 23:37:48'),
('reg_33', '2026-05-02 23:37:48'),
('reg_36', '2026-05-02 23:58:18'),
('reg_37', '2026-05-04 01:33:31'),
('reg_38', '2026-05-04 01:33:31'),
('reg_4', '2026-05-02 23:12:13'),
('reg_5', '2026-05-02 23:12:13'),
('reg_6', '2026-05-02 23:12:13'),
('reg_7', '2026-05-02 23:12:13'),
('reg_8', '2026-05-02 23:12:13'),
('reg_9', '2026-05-02 23:12:13'),
('trip_done_15', '2026-05-02 23:12:13'),
('trip_done_16', '2026-05-02 23:12:13'),
('trip_done_17', '2026-05-02 23:12:13'),
('trip_done_18', '2026-05-02 23:12:13'),
('trip_done_19', '2026-05-02 23:12:13'),
('trip_done_20', '2026-05-02 23:12:13'),
('ver_1_1777502766', '2026-05-02 23:12:13'),
('ver_10_1777749879', '2026-05-02 23:12:13'),
('ver_11_1777749896', '2026-05-02 23:12:13'),
('ver_2_1777503169', '2026-05-02 23:12:13'),
('ver_3_1777503173', '2026-05-02 23:12:13'),
('ver_4_1777593387', '2026-05-02 23:12:13'),
('ver_5_1777593436', '2026-05-02 23:12:13'),
('ver_6_1777597289', '2026-05-02 23:12:13'),
('ver_7_1777597299', '2026-05-02 23:12:13'),
('ver_8_1777726882', '2026-05-02 23:12:13'),
('ver_9_1777726884', '2026-05-02 23:12:13');

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
(10, 16, 16, 1000.00, 5, 'accepted', '2026-04-29 21:39:56'),
(11, 17, 16, 1800.00, 5, 'accepted', '2026-04-29 22:56:32'),
(12, 18, 24, 1170.00, 5, 'accepted', '2026-05-01 00:00:13'),
(13, 19, 26, 1190.00, 5, 'accepted', '2026-05-01 00:49:51'),
(14, 20, 24, 900.00, 5, 'accepted', '2026-05-02 13:09:53'),
(15, 21, 24, 191892.00, 5, 'accepted', '2026-05-02 14:02:20'),
(16, 22, 24, 275675.00, 5, 'accepted', '2026-05-02 14:21:04'),
(17, 23, 24, 315.00, 5, 'rejected', '2026-05-02 19:17:56'),
(18, 14, 24, 3.00, 5, 'rejected', '2026-05-02 19:18:07'),
(19, 10, 24, 2000.00, 5, 'rejected', '2026-05-02 19:18:58'),
(20, 24, 24, 720.00, 5, 'accepted', '2026-05-04 23:35:28'),
(21, 25, 24, 291892.00, 5, 'accepted', '2026-05-05 00:00:11'),
(22, 26, 24, 4091.00, 5, 'accepted', '2026-05-05 00:09:56'),
(23, 27, 24, 50.00, 5, 'accepted', '2026-05-05 00:11:48'),
(24, 28, 24, 409.00, 5, 'accepted', '2026-05-05 00:19:59'),
(25, 29, 24, 400.00, 5, 'accepted', '2026-05-05 00:30:06'),
(26, 30, 24, 20.00, 5, 'accepted', '2026-05-05 18:50:48'),
(27, 31, 41, 1530.00, 5, 'accepted', '2026-05-07 06:20:14'),
(28, 32, 41, 1710.00, 5, 'accepted', '2026-05-07 06:28:35'),
(29, 34, 41, 4317.00, 5, 'accepted', '2026-05-07 08:21:17'),
(30, 35, 24, 1620.00, 5, 'accepted', '2026-05-07 12:31:19'),
(31, 36, 24, 300.00, 5, 'accepted', '2026-05-11 16:49:41'),
(32, 6, 24, 585.00, 5, 'rejected', '2026-05-11 17:52:33'),
(33, 37, 24, 1530.00, 5, 'accepted', '2026-05-11 18:30:32'),
(34, 38, 24, 2910.00, 5, 'rejected', '2026-05-11 20:21:15'),
(35, 39, 24, 478979.00, 5, 'accepted', '2026-05-11 20:22:44'),
(36, 41, 24, 1530.00, 5, 'rejected', '2026-05-11 21:25:44'),
(37, 42, 24, 1620.00, 5, 'accepted', '2026-05-12 19:01:14'),
(38, 43, 46, 1300.00, 5, 'accepted', '2026-05-12 19:32:28'),
(39, 45, 24, 3000.00, 5, 'accepted', '2026-05-12 20:09:53'),
(40, 46, 46, 1620.00, 5, 'accepted', '2026-05-12 20:27:49'),
(41, 46, 24, 1500.00, 5, 'rejected', '2026-05-12 20:28:20'),
(42, 46, 41, 1300.00, 5, 'rejected', '2026-05-12 20:29:26'),
(43, 47, 41, 1710.00, 5, 'accepted', '2026-05-12 20:58:43'),
(44, 44, 24, 4100.00, 5, 'rejected', '2026-05-13 00:40:49'),
(45, 8, 24, 4950.00, 5, 'rejected', '2026-05-14 03:35:22'),
(46, 4, 24, 1100.00, 5, 'rejected', '2026-05-14 03:35:34'),
(47, 2, 24, 900.00, 5, 'rejected', '2026-05-14 03:51:43'),
(48, 5, 46, 3780.00, 5, 'rejected', '2026-05-14 04:00:25'),
(49, 8, 41, 4100.00, 5, 'rejected', '2026-05-14 04:02:08'),
(50, 5, 26, 3500.00, 5, 'pending', '2026-05-14 04:04:37'),
(51, 48, 55, 1530.00, 5, 'accepted', '2026-05-14 08:22:22'),
(52, 49, 46, 1260.00, 5, 'rejected', '2026-05-14 21:41:10'),
(53, 49, 24, 1200.00, 5, 'rejected', '2026-05-14 21:41:43'),
(54, 49, 41, 1540.00, 5, 'rejected', '2026-05-14 21:44:41');

-- --------------------------------------------------------

--
-- بنية الجدول `compliance_documents`
--

CREATE TABLE `compliance_documents` (
  `document_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `truck_id` int(11) DEFAULT NULL,
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `compliance_documents`
--

INSERT INTO `compliance_documents` (`document_id`, `user_id`, `truck_id`, `document_type`, `document_url`, `issue_date`, `expiry_date`, `is_verified`, `verified_by`, `verified_at`, `verification_notes`, `uploaded_at`, `created_at`, `updated_at`) VALUES
(1, 21, NULL, 'commercial_registration', 'commercial_docs/1777502113477-IMG_20260423_140242.jpg', NULL, '2099-12-31', 1, NULL, '2026-04-29 22:46:06', NULL, '2026-04-29 22:35:13', '2026-04-29 22:35:13', '2026-04-29 22:46:06'),
(2, 22, NULL, 'driver_license', 'licenses/1777502867757-35.pdf', '2026-04-08', '2026-04-30', 1, NULL, '2026-04-29 22:52:49', NULL, '2026-04-29 22:47:47', '2026-04-29 22:47:47', '2026-04-29 22:52:49'),
(3, 23, NULL, 'commercial_registration', 'commercial_docs/1777502962834-IMG_20260423_140242.jpg', NULL, '2099-12-31', 1, NULL, '2026-04-29 22:52:53', NULL, '2026-04-29 22:49:22', '2026-04-29 22:49:22', '2026-04-29 22:52:53'),
(4, 24, NULL, 'driver_license', 'licenses/1777593367673-IMG_20260423_140242.jpg', '2026-05-01', '2026-05-16', 1, NULL, '2026-04-30 23:56:27', NULL, '2026-04-30 23:56:07', '2026-04-30 23:56:07', '2026-04-30 23:56:27'),
(5, 25, NULL, 'commercial_registration', 'commercial_docs/1777593424418-35.pdf', NULL, '2099-12-31', 1, NULL, '2026-04-30 23:57:16', NULL, '2026-04-30 23:57:04', '2026-04-30 23:57:04', '2026-04-30 23:57:16'),
(6, 26, NULL, 'driver_license', 'licenses/1777596323268-IMG_20260501_034410.jpg', '2026-05-01', '2026-05-30', 1, NULL, '2026-05-01 01:01:29', NULL, '2026-05-01 00:45:23', '2026-05-01 00:45:23', '2026-05-01 01:01:29'),
(7, 27, NULL, 'commercial_registration', 'commercial_docs/1777596437952-IMG_20260501_034410.jpg', NULL, '2099-12-31', 1, NULL, '2026-05-01 01:01:39', NULL, '2026-05-01 00:47:18', '2026-05-01 00:47:18', '2026-05-01 01:01:39'),
(8, 28, NULL, 'commercial_registration', 'commercial_docs/1777726450666-IMG_20260501_034410.jpg', NULL, '2099-12-31', 1, NULL, '2026-05-02 13:01:22', NULL, '2026-05-02 12:54:10', '2026-05-02 12:54:10', '2026-05-02 13:01:22'),
(9, 29, NULL, 'driver_license', 'licenses/1777726636357-IMG_20260501_034410.jpg', '2026-05-01', '2026-05-02', 1, NULL, '2026-05-02 13:01:24', NULL, '2026-05-02 12:57:16', '2026-05-02 12:57:16', '2026-05-02 13:01:24'),
(10, 30, NULL, 'commercial_registration', 'commercial_docs/1777749756237-IMG_20260501_034410.jpg', NULL, '2099-12-31', 2, NULL, '2026-05-02 19:24:39', NULL, '2026-05-02 19:22:36', '2026-05-02 19:22:36', '2026-05-02 19:24:39'),
(11, 31, NULL, 'commercial_registration', 'commercial_docs/1777749799884-IMG_20260501_034410.jpg', NULL, '2099-12-31', 1, NULL, '2026-05-02 19:24:56', NULL, '2026-05-02 19:23:19', '2026-05-02 19:23:19', '2026-05-02 19:24:56'),
(12, 32, NULL, 'commercial_registration', 'commercial_docs/1777763663255-IMG_20260503_021356.jpg', NULL, '2099-12-31', 2, NULL, '2026-05-07 07:14:36', NULL, '2026-05-02 23:14:23', '2026-05-02 23:14:23', '2026-05-07 07:14:36'),
(13, 33, NULL, 'commercial_registration', 'commercial_docs/1777764565840-IMG_20260503_021356.jpg', NULL, '2099-12-31', 2, NULL, '2026-05-07 07:57:13', NULL, '2026-05-02 23:29:25', '2026-05-02 23:29:25', '2026-05-07 07:57:13'),
(14, 36, NULL, 'driver_license', 'licenses/1777765488950-IMG_20260503_021356.jpg', '2026-05-03', '2026-05-12', 2, NULL, '2026-05-07 07:57:15', NULL, '2026-05-02 23:44:49', '2026-05-02 23:44:49', '2026-05-07 07:57:15'),
(15, 37, NULL, 'commercial_registration', 'commercial_docs/1777855147604-IMG_20260503_021356.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-04 00:39:07', '2026-05-04 00:39:07', '2026-05-04 00:39:07'),
(16, 38, NULL, 'driver_license', 'licenses/1777855418805-IMG_20260503_021356.jpg', '2026-05-04', '2026-05-29', 0, NULL, NULL, NULL, '2026-05-04 00:43:38', '2026-05-04 00:43:38', '2026-05-04 00:43:38'),
(17, 39, NULL, 'commercial_registration', 'commercial_docs/1778007333835-IMG_20260503_021356.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-05 18:55:33', '2026-05-05 18:55:33', '2026-05-05 18:55:33'),
(18, 40, NULL, 'commercial_registration', 'commercial_docs/1778134551474-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-07 06:15:51', '2026-05-07 06:15:51', '2026-05-07 06:15:51'),
(19, 41, NULL, 'driver_license', 'licenses/1778134644406-IMG_20260501_034410.jpg', '2026-05-01', '2026-05-30', 0, NULL, NULL, NULL, '2026-05-07 06:17:24', '2026-05-07 06:17:24', '2026-05-07 06:17:24'),
(20, 42, NULL, 'commercial_registration', 'commercial_docs/1778140090481-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-07 07:48:10', '2026-05-07 07:48:10', '2026-05-07 07:48:10'),
(21, 43, NULL, 'driver_license', 'licenses/1778140562920-IMG_20260501_034410.jpg', '2026-05-07', '2026-05-29', 0, NULL, NULL, NULL, '2026-05-07 07:56:03', '2026-05-07 07:56:03', '2026-05-07 07:56:03'),
(22, 44, NULL, 'commercial_registration', 'commercial_docs/1778140777157-35.pdf', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-07 07:59:37', '2026-05-07 07:59:37', '2026-05-07 07:59:37'),
(23, 24, NULL, 'vehicle_insurance', 'vehicle_insurance/1778520795208-ab37eead-3078-4df9-bc45-56d3bc9bce0b-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-11 17:33:15', '2026-05-11 17:33:15', '2026-05-11 17:33:15'),
(24, 24, NULL, 'vehicle_insurance', 'vehicle_insurance/1778520870180-f971ee53-4e5d-4382-92b5-80ec2769c5a7-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-11 17:34:30', '2026-05-11 17:34:30', '2026-05-11 17:34:30'),
(25, 24, NULL, 'vehicle_insurance', 'vehicle_insurance/1778521006770-ca254a4c-99f7-45c8-a212-8d7c91242e4e-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-11 17:36:46', '2026-05-11 17:36:46', '2026-05-11 17:36:46'),
(26, 24, 6, 'vehicle_insurance', 'vehicle_insurance/1778521659335-0e988a0a-9e1c-472b-b261-c0a7c13555d7-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-11 17:47:39', '2026-05-11 17:47:39', '2026-05-11 17:47:39'),
(27, 45, NULL, 'commercial_registration', 'commercial_docs/1778523283453-18ed4aad-af0b-4c3d-aec9-2da2a8ce289c-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-11 18:14:43', '2026-05-11 18:14:43', '2026-05-11 18:14:43'),
(28, 24, 13, 'vehicle_insurance', 'vehicle_insurance/1778611031578-fbd7c18a-55b3-4326-9832-1ef6df6be699-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-12 18:37:11', '2026-05-12 18:37:11', '2026-05-12 18:37:11'),
(29, 46, NULL, 'driver_license', 'licenses/1778613870888-d5fb01a5-f092-45dd-94b7-0f138b6db85c-IMG_20260501_034410.jpg', '2026-05-13', '2027-05-12', 0, NULL, NULL, NULL, '2026-05-12 19:24:30', '2026-05-12 19:24:30', '2026-05-12 19:24:30'),
(30, 47, NULL, 'commercial_registration', 'commercial_docs/1778613925625-e3b0aa42-043b-4ae1-969c-8db5266e7800-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-12 19:25:25', '2026-05-12 19:25:25', '2026-05-12 19:25:25'),
(31, 48, NULL, 'commercial_registration', 'commercial_docs/1778632908664-8ce00154-cf8e-4446-a67b-0b0885b044e7-acce5ebd-a0f8-4ca6-9962-76c6db725ef4.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-13 00:41:48', '2026-05-13 00:41:48', '2026-05-13 00:41:48'),
(33, 50, NULL, 'commercial_registration', 'commercial_docs/1778720958421-1eabd6e3-4ffd-4b16-847d-89630ca81348-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-14 01:09:18', '2026-05-14 01:09:18', '2026-05-14 01:09:18'),
(34, 51, NULL, 'commercial_registration', 'commercial_docs/1778721118903-f67a0997-8610-4221-a01a-8344f20fa90b-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-14 01:11:59', '2026-05-14 01:11:59', '2026-05-14 01:11:59'),
(35, 52, NULL, 'commercial_registration', 'commercial_docs/1778722091751-bafaeb03-43c2-4b84-ac69-852bc7f1fd9b-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-14 01:28:11', '2026-05-14 01:28:11', '2026-05-14 01:28:11'),
(36, 53, NULL, 'commercial_registration', 'commercial_docs/1778722881830-a6827142-534e-4b96-953c-353070437fcf-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-14 01:41:21', '2026-05-14 01:41:21', '2026-05-14 01:41:21'),
(37, 54, NULL, 'commercial_registration', 'commercial_docs/1778734541350-1bd9f7e7-dad5-4119-9255-d466e8711641-IMG_20260501_034410.jpg', NULL, '2099-12-31', 0, NULL, NULL, NULL, '2026-05-14 04:55:41', '2026-05-14 04:55:41', '2026-05-14 04:55:41'),
(38, 55, NULL, 'driver_license', 'licenses/1778744418044-da139bc3-ec51-4380-9d16-63b58e561c75-images.jpeg', '2026-05-31', '2027-05-27', 0, NULL, NULL, NULL, '2026-05-14 07:40:18', '2026-05-14 07:40:18', '2026-05-14 07:40:18');

-- --------------------------------------------------------

--
-- بنية الجدول `contracts`
--

CREATE TABLE `contracts` (
  `id` int(11) NOT NULL,
  `shipment_id` int(11) NOT NULL,
  `bid_id` int(11) NOT NULL,
  `driver_id` int(11) NOT NULL,
  `shipper_id` int(11) NOT NULL,
  `pdf_key` varchar(512) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `contracts`
--

INSERT INTO `contracts` (`id`, `shipment_id`, `bid_id`, `driver_id`, `shipper_id`, `pdf_key`, `created_at`) VALUES
(1, 18, 12, 24, 25, 'contracts/shipment-18-1777593650892.pdf', '2026-05-01 00:00:50'),
(2, 19, 13, 26, 27, 'contracts/shipment-19-1777596626394.pdf', '2026-05-01 00:50:26'),
(3, 20, 14, 24, 28, 'contracts/shipment-20-1777727406927.pdf', '2026-05-02 13:10:06'),
(4, 21, 15, 24, 28, 'contracts/shipment-21-1777730617471.pdf', '2026-05-02 14:03:37'),
(5, 22, 16, 24, 28, 'contracts/shipment-22-1777731720218.pdf', '2026-05-02 14:22:00'),
(6, 24, 20, 24, 25, 'contracts/shipment-24-1777937822884.pdf', '2026-05-04 23:37:02'),
(7, 25, 21, 24, 25, 'contracts/shipment-25-1777939239399.pdf', '2026-05-05 00:00:39'),
(8, 28, 24, 24, 25, 'contracts/shipment-28-1777940429246.pdf', '2026-05-05 00:20:29'),
(9, 29, 25, 24, 25, 'contracts/shipment-29-1777941032475.pdf', '2026-05-05 00:30:32'),
(10, 30, 26, 24, 25, 'contracts/shipment-30-1778007064616.pdf', '2026-05-05 18:51:04'),
(11, 31, 27, 41, 40, 'contracts/shipment-31-1778134836599.pdf', '2026-05-07 06:20:36'),
(12, 32, 28, 41, 40, 'contracts/shipment-32-1778135774219.pdf', '2026-05-07 06:36:14'),
(13, 34, 29, 41, 40, 'contracts/shipment-34-1778142106166.pdf', '2026-05-07 08:21:46'),
(14, 35, 30, 24, 40, 'contracts/shipment-35-1778157110972.pdf', '2026-05-07 12:31:51'),
(15, 36, 31, 24, 40, 'contracts/shipment-36-1778518195079.pdf', '2026-05-11 16:49:55'),
(16, 37, 33, 24, 40, 'contracts/shipment-37-1778524269751.pdf', '2026-05-11 18:31:09'),
(17, 39, 35, 24, 40, 'contracts/shipment-39-1778531013074.pdf', '2026-05-11 20:23:33'),
(18, 42, 37, 24, 40, 'contracts/shipment-42-1778612610507.pdf', '2026-05-12 19:03:30'),
(19, 43, 38, 46, 47, 'contracts/shipment-43-1778614399654.pdf', '2026-05-12 19:33:19'),
(20, 45, 39, 24, 40, 'contracts/shipment-45-1778616604898.pdf', '2026-05-12 20:10:04'),
(21, 46, 40, 46, 40, 'contracts/shipment-46-1778618588388.pdf', '2026-05-12 20:43:08'),
(22, 47, 43, 41, 40, 'contracts/shipment-47-1778619534349.pdf', '2026-05-12 20:58:54'),
(23, 48, 51, 55, 52, 'contracts/shipment-48-1778746970775.pdf', '2026-05-14 08:22:50');

-- --------------------------------------------------------

--
-- بنية الجدول `disputes`
--

CREATE TABLE `disputes` (
  `id` int(11) NOT NULL,
  `shipment_id` int(11) NOT NULL,
  `driver_id` int(11) NOT NULL,
  `amount` decimal(15,2) NOT NULL DEFAULT 0.00,
  `dispute_reason` text DEFAULT NULL,
  `status` enum('open','approved','rejected') NOT NULL DEFAULT 'open',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `resolved_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- بنية الجدول `messages`
--

CREATE TABLE `messages` (
  `id` int(11) NOT NULL,
  `shipment_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `receiver_id` int(11) NOT NULL,
  `message_type` enum('text','image','video','location') NOT NULL DEFAULT 'text',
  `message` text NOT NULL,
  `media_key` varchar(1000) DEFAULT NULL,
  `media_mime_type` varchar(120) DEFAULT NULL,
  `media_size_bytes` bigint(20) DEFAULT NULL,
  `media_file_name` varchar(255) DEFAULT NULL,
  `thumbnail_key` varchar(1000) DEFAULT NULL,
  `location_lat` decimal(10,7) DEFAULT NULL,
  `location_lng` decimal(10,7) DEFAULT NULL,
  `location_label` varchar(255) DEFAULT NULL,
  `delivered_at` datetime DEFAULT NULL,
  `read_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `messages`
--

INSERT INTO `messages` (`id`, `shipment_id`, `sender_id`, `receiver_id`, `message_type`, `message`, `media_key`, `media_mime_type`, `media_size_bytes`, `media_file_name`, `thumbnail_key`, `location_lat`, `location_lng`, `location_label`, `delivered_at`, `read_at`, `created_at`) VALUES
(1, 15, 15, 16, 'text', 'تاليي', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-04-29 19:34:42'),
(2, 15, 15, 16, 'text', 'sdfdsfdsf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-04-29 20:45:59'),
(3, 18, 25, 24, 'text', 'السلام عليكم', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:42:17', '2026-05-12 09:42:17', '2026-05-01 00:04:07'),
(4, 18, 24, 25, 'text', 'SADASDASDSDFDSF', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-01 00:13:31'),
(5, 19, 26, 27, 'text', 'السلام عليكم وصلت المكان', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-01 00:52:43'),
(6, 19, 27, 26, 'text', 'تمام كلم العامل برا يساعدك', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-01 00:53:58'),
(7, 20, 24, 28, 'text', 'adasdsads', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-02 13:10:40'),
(8, 20, 24, 28, 'text', 'adasdsads', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-02 13:10:41'),
(9, 20, 28, 24, 'text', 'dfgfdgdfgfd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:42:11', '2026-05-12 09:42:11', '2026-05-02 13:10:55'),
(10, 20, 24, 28, 'text', 'hjghjg', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-02 13:11:43'),
(11, 20, 24, 28, 'text', 'sdfdsffdfsdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-02 13:11:51'),
(12, 21, 28, 24, 'text', 'fdfdgdg', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:42:06', '2026-05-12 09:42:06', '2026-05-02 14:05:14'),
(13, 21, 28, 24, 'text', 'SDFDSFSDF', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:42:06', '2026-05-12 09:42:06', '2026-05-02 19:07:08'),
(14, 32, 41, 40, 'text', 'السلام عليهم استلمت الشحنة', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:46:37', '2026-05-12 09:46:37', '2026-05-07 07:33:26'),
(15, 32, 41, 40, 'text', 'اللا', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:46:37', '2026-05-12 09:46:37', '2026-05-07 08:12:28'),
(16, 34, 41, 40, 'text', 'السلام عليكم', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:46:35', '2026-05-12 09:46:35', '2026-05-07 08:23:10'),
(17, 39, 24, 40, 'text', 'تتالللا', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:44:41', '2026-05-12 09:44:41', '2026-05-11 20:24:37'),
(18, 39, 24, 40, 'text', 'تتالللا', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:44:41', '2026-05-12 09:44:41', '2026-05-11 20:24:38'),
(19, 39, 40, 24, 'text', 'حسين صورتك وين ذي', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:41:58', '2026-05-12 09:41:58', '2026-05-12 05:38:46'),
(20, 39, 40, 24, 'text', 'السلام عليكم حسين هذي صورتك في تركيا؟', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:41:58', '2026-05-12 09:41:58', '2026-05-12 05:43:20'),
(21, 39, 24, 40, 'text', 'كيف عرفت انت مين ؟', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:44:41', '2026-05-12 09:44:41', '2026-05-12 05:44:27'),
(22, 39, 24, 40, 'text', 'تعرفني اعرفك؟!!', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:44:41', '2026-05-12 09:44:41', '2026-05-12 05:44:48'),
(23, 39, 40, 24, 'text', 'ااا', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:44:58', '2026-05-12 09:44:58', '2026-05-12 06:44:50'),
(24, 39, 40, 24, 'text', 'dfdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:45:08', '2026-05-12 09:45:09', '2026-05-12 06:45:08'),
(25, 39, 24, 40, 'text', 'fdfdgfd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:45:17', '2026-05-12 09:45:17', '2026-05-12 06:45:17'),
(26, 39, 24, 40, 'text', 'gfjghj', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:45:27', '2026-05-12 09:45:27', '2026-05-12 06:45:27'),
(27, 39, 40, 24, 'text', 'uiouuou', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 09:47:25', '2026-05-12 09:47:25', '2026-05-12 06:46:53'),
(28, 39, 40, 24, 'text', 'sddfgfdgfd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:06:19', '2026-05-12 10:06:19', '2026-05-12 07:06:11'),
(29, 39, 24, 40, 'text', 'fdggdfgd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:06:23', '2026-05-12 10:06:23', '2026-05-12 07:06:23'),
(30, 39, 24, 40, 'text', 'gdfgdg', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:06:28', '2026-05-12 10:06:28', '2026-05-12 07:06:28'),
(31, 39, 24, 40, 'text', 'dfgfd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:06:31', '2026-05-12 10:06:31', '2026-05-12 07:06:31'),
(32, 39, 40, 24, 'text', 'dfgfdg', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:06:34', '2026-05-12 10:06:34', '2026-05-12 07:06:34'),
(33, 39, 40, 24, 'text', 'gdfgdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:06:58', '2026-05-12 10:06:58', '2026-05-12 07:06:50'),
(34, 39, 24, 40, 'text', 'dssdss', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:11:37', '2026-05-12 10:11:37', '2026-05-12 07:11:37'),
(35, 39, 24, 40, 'text', 'sfdsfsf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:11:43', '2026-05-12 10:11:43', '2026-05-12 07:11:43'),
(36, 39, 24, 40, 'text', 'sdfdsfs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 10:11:49', '2026-05-12 10:11:49', '2026-05-12 07:11:49'),
(37, 39, 40, 24, 'location', 'موقع حالي', NULL, NULL, NULL, NULL, NULL, 37.4219983, -122.0840000, 'موقع حالي', '2026-05-12 20:46:30', '2026-05-12 20:46:30', '2026-05-12 17:36:17'),
(38, 39, 40, 24, 'image', '', 'chat/39/40/1778607436902-ec50fd52-f048-4c3e-8d6e-131e31e8c071-video-1778607426877.mp4', 'application/octet-stream', 177600, 'video-1778607426877.mp4', NULL, NULL, NULL, NULL, '2026-05-12 20:46:30', '2026-05-12 20:46:30', '2026-05-12 17:37:16'),
(39, 39, 40, 24, 'video', '', 'chat/39/40/1778607922146-593deb2f-30af-4c34-827e-5d3d13b7f509-video-1778607911814.mp4', 'application/octet-stream', 121408, 'video-1778607911814.mp4', NULL, NULL, NULL, NULL, '2026-05-12 20:46:30', '2026-05-12 20:46:30', '2026-05-12 17:45:22'),
(40, 35, 24, 40, 'image', '', 'chat/35/24/1778609140140-352fea1a-ff8e-46c5-8efa-b4f3b323339f-photo-1778609129958.jpg', 'application/octet-stream', 22941, 'photo-1778609129958.jpg', NULL, NULL, NULL, NULL, '2026-05-12 21:47:05', '2026-05-12 21:47:05', '2026-05-12 18:05:40'),
(41, 42, 40, 24, 'text', 'sdfdsfsfs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:02:16', '2026-05-12 23:02:16', '2026-05-12 19:06:45'),
(42, 43, 46, 47, 'text', 'dfgfdgd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 22:41:52', '2026-05-12 22:41:52', '2026-05-12 19:41:26'),
(43, 43, 46, 46, 'text', 'gfghhfgh', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 22:43:29', '2026-05-12 22:43:29', '2026-05-12 19:41:54'),
(44, 43, 46, 46, 'text', 'dfgdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 22:43:29', '2026-05-12 22:43:29', '2026-05-12 19:41:58'),
(45, 43, 46, 46, 'text', 'dggfdgdfg', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 22:43:29', '2026-05-12 22:43:29', '2026-05-12 19:42:22'),
(46, 43, 46, 46, 'text', 'fdsfsfsdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 22:43:29', '2026-05-12 22:43:29', '2026-05-12 19:43:02'),
(47, 43, 46, 47, 'text', 'dfdsfdsf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 22:57:31', '2026-05-12 22:57:31', '2026-05-12 19:43:34'),
(48, 43, 46, 47, 'text', 'sadasdsa', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 22:57:31', '2026-05-12 22:57:31', '2026-05-12 19:57:08'),
(49, 43, 46, 46, 'text', 'adsada', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:00:38', '2026-05-12 23:00:38', '2026-05-12 19:57:33'),
(50, 43, 47, 46, 'text', 'sdsadas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:00:38', '2026-05-12 23:00:38', '2026-05-12 19:58:09'),
(51, 43, 47, 47, 'text', 'sdfdsfs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:00:45', '2026-05-12 23:00:45', '2026-05-12 20:00:39'),
(52, 43, 47, 46, 'text', 'dsfsdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:03:47', '2026-05-12 23:03:47', '2026-05-12 20:00:47'),
(53, 43, 47, 46, 'text', 'dsfsdfds', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:03:47', '2026-05-12 23:03:47', '2026-05-12 20:01:04'),
(54, 43, 47, 47, 'text', 'sdfsdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:01:08', '2026-05-12 23:01:08', '2026-05-12 20:01:08'),
(55, 43, 47, 47, 'text', 'sdfsdfs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:01:17', '2026-05-12 23:01:17', '2026-05-12 20:01:17'),
(56, 43, 47, 46, 'text', 'dfsdfs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:03:47', '2026-05-12 23:03:47', '2026-05-12 20:01:20'),
(57, 43, 47, 46, 'text', 'dsadad', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:07:18', '2026-05-12 23:07:18', '2026-05-12 20:03:50'),
(58, 43, 47, 47, 'text', 'sadsad', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:03:53', '2026-05-12 23:03:53', '2026-05-12 20:03:53'),
(59, 43, 46, 47, 'text', 'dsfsdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:07:27', '2026-05-12 23:07:27', '2026-05-12 20:07:21'),
(60, 43, 47, 46, 'text', 'dsfdsfs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:07:29', '2026-05-12 23:07:29', '2026-05-12 20:07:29'),
(61, 43, 46, 47, 'text', 'sdfdsfsd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:07:32', '2026-05-12 23:07:32', '2026-05-12 20:07:32'),
(62, 43, 47, 46, 'text', 'dsfdsfsd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:07:35', '2026-05-12 23:07:35', '2026-05-12 20:07:35'),
(63, 43, 46, 47, 'text', 'sdfdsfs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:07:39', '2026-05-12 23:07:39', '2026-05-12 20:07:39'),
(64, 43, 47, 46, 'text', 'dsfsdfsdf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:07:42', '2026-05-12 23:07:42', '2026-05-12 20:07:42'),
(65, 45, 40, 24, 'text', 'sdfdsfsd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:10:57', '2026-05-12 23:10:57', '2026-05-12 20:10:33'),
(66, 45, 24, 40, 'text', 'fghfghgfh', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:20:26', '2026-05-12 23:20:26', '2026-05-12 20:20:18'),
(67, 45, 40, 24, 'text', 'fhgfhfh', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:20:27', '2026-05-12 23:20:27', '2026-05-12 20:20:27'),
(68, 45, 24, 40, 'text', 'gfhfghf', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:20:30', '2026-05-12 23:20:30', '2026-05-12 20:20:30'),
(69, 45, 40, 24, 'text', 'ghfh', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:20:36', '2026-05-12 23:20:36', '2026-05-12 20:20:36'),
(70, 45, 40, 24, 'video', '', 'chat/45/40/1778617271831-ce328c4a-7fc3-4ad2-b720-3fb89eb69a68-video-1778617255511.mp4', 'application/octet-stream', 114260, 'video-1778617255511.mp4', NULL, NULL, NULL, NULL, '2026-05-12 23:21:11', '2026-05-12 23:21:11', '2026-05-12 20:21:11'),
(71, 45, 40, 24, 'text', 'sadasd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:23:45', '2026-05-12 23:23:45', '2026-05-12 20:23:38'),
(72, 45, 24, 40, 'text', 'asdasd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:23:48', '2026-05-12 23:23:48', '2026-05-12 20:23:48'),
(73, 45, 40, 24, 'text', 'sadasd', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 23:23:53', '2026-05-12 23:23:53', '2026-05-12 20:23:53'),
(74, 46, 40, 46, 'text', 'سشيشسيش', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-12 20:46:01'),
(75, 48, 55, 52, 'text', 'السلام عليكم', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-14 11:24:15', '2026-05-14 11:24:15', '2026-05-14 08:24:04'),
(76, 48, 52, 55, 'text', 'افضل موقع الاستلام', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-14 11:24:35', '2026-05-14 11:24:35', '2026-05-14 08:24:35'),
(77, 48, 52, 55, 'location', 'موقع محدد', NULL, NULL, NULL, NULL, NULL, 37.4176523, -122.0783721, 'موقع محدد', '2026-05-14 11:24:49', '2026-05-14 11:24:49', '2026-05-14 08:24:49'),
(78, 47, 41, 40, 'location', 'موقع حالي', NULL, NULL, NULL, NULL, NULL, 37.4219983, -122.0840000, 'موقع حالي', NULL, NULL, '2026-05-21 03:02:03');

-- --------------------------------------------------------

--
-- بنية الجدول `notifications`
--

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `related_shipment_id` int(11) DEFAULT NULL,
  `related_bid_id` int(11) DEFAULT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `notifications`
--

INSERT INTO `notifications` (`id`, `user_id`, `title`, `message`, `related_shipment_id`, `related_bid_id`, `is_read`, `created_at`) VALUES
(1, 15, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 0, '2026-04-30 23:51:46'),
(2, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 1170 ريال للشحنة #18', NULL, NULL, 0, '2026-05-01 00:00:13'),
(3, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 18', NULL, NULL, 0, '2026-05-01 00:00:50'),
(4, 25, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 1, '2026-05-01 00:14:44'),
(5, 27, 'عرض جديد', 'حصلت على عرض جديد بسعر 1190 ريال للشحنة #19', NULL, NULL, 0, '2026-05-01 00:49:51'),
(6, 26, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 19', NULL, NULL, 0, '2026-05-01 00:50:26'),
(7, 27, 'تقييم جديد', 'حصلت على تقييم 1 نجمة', NULL, NULL, 0, '2026-05-01 00:57:37'),
(8, 28, 'عرض جديد', 'حصلت على عرض جديد بسعر 900 ريال للشحنة #20', NULL, NULL, 1, '2026-05-02 13:09:53'),
(9, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 20', NULL, NULL, 0, '2026-05-02 13:10:06'),
(10, 28, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 1, '2026-05-02 13:14:28'),
(11, 28, 'عرض جديد', 'حصلت على عرض جديد بسعر 191892 ريال للشحنة #21', NULL, NULL, 0, '2026-05-02 14:02:20'),
(12, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 21', NULL, NULL, 0, '2026-05-02 14:03:37'),
(13, 28, 'عرض جديد', 'حصلت على عرض جديد بسعر 275675 ريال للشحنة #22', NULL, NULL, 0, '2026-05-02 14:21:04'),
(14, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 22', NULL, NULL, 0, '2026-05-02 14:22:00'),
(15, 28, 'عرض جديد', 'حصلت على عرض جديد بسعر 315 ريال للشحنة #23', NULL, NULL, 0, '2026-05-02 19:17:56'),
(16, 9, 'عرض جديد', 'حصلت على عرض جديد بسعر 3 ريال للشحنة #14', NULL, NULL, 0, '2026-05-02 19:18:07'),
(17, 9, 'عرض جديد', 'حصلت على عرض جديد بسعر 2000 ريال للشحنة #10', NULL, NULL, 0, '2026-05-02 19:18:58'),
(18, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 720 ريال للشحنة #24', NULL, NULL, 0, '2026-05-04 23:35:28'),
(19, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 24', NULL, NULL, 0, '2026-05-04 23:37:02'),
(20, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 291892 ريال للشحنة #25', NULL, NULL, 0, '2026-05-05 00:00:11'),
(21, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 25', NULL, NULL, 0, '2026-05-05 00:00:39'),
(22, 25, 'عقد إلكتروني', 'تم إنشاء عقد رقم #7 للشحنة #25 بقيمة ٢٩١٬٨٩٢ ريال', NULL, NULL, 0, '2026-05-05 00:00:39'),
(23, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #7 للشحنة #25 بقيمة ٢٩١٬٨٩٢ ريال', NULL, NULL, 0, '2026-05-05 00:00:39'),
(24, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 4091 ريال للشحنة #26', NULL, NULL, 1, '2026-05-05 00:09:56'),
(25, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 26', NULL, NULL, 0, '2026-05-05 00:10:10'),
(26, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 50 ريال للشحنة #27', NULL, NULL, 0, '2026-05-05 00:11:48'),
(27, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 27', NULL, NULL, 0, '2026-05-05 00:12:03'),
(28, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 409 ريال للشحنة #28', NULL, NULL, 0, '2026-05-05 00:19:59'),
(29, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 28', NULL, NULL, 0, '2026-05-05 00:20:28'),
(30, 25, 'عقد إلكتروني', 'تم إنشاء عقد رقم #8 للشحنة #28 بقيمة ٤٠٩ ريال', NULL, NULL, 0, '2026-05-05 00:20:29'),
(31, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #8 للشحنة #28 بقيمة ٤٠٩ ريال', NULL, NULL, 0, '2026-05-05 00:20:29'),
(32, 25, 'تقييم جديد', 'حصلت على تقييم 2 نجمة', NULL, NULL, 0, '2026-05-05 00:28:29'),
(33, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 400 ريال للشحنة #29', NULL, NULL, 0, '2026-05-05 00:30:06'),
(34, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 29', NULL, NULL, 0, '2026-05-05 00:30:31'),
(35, 25, 'عقد إلكتروني', 'تم إنشاء عقد رقم #9 للشحنة #29 بقيمة ٤٠٠ ريال', NULL, NULL, 1, '2026-05-05 00:30:32'),
(36, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #9 للشحنة #29 بقيمة ٤٠٠ ريال', NULL, NULL, 0, '2026-05-05 00:30:32'),
(37, 25, 'عرض جديد', 'حصلت على عرض جديد بسعر 20 ريال للشحنة #30', NULL, NULL, 0, '2026-05-05 18:50:48'),
(38, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 30', NULL, NULL, 0, '2026-05-05 18:51:03'),
(39, 25, 'عقد إلكتروني', 'تم إنشاء عقد رقم #10 للشحنة #30 بقيمة ٢٠ ريال', NULL, NULL, 0, '2026-05-05 18:51:04'),
(40, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #10 للشحنة #30 بقيمة ٢٠ ريال', NULL, NULL, 0, '2026-05-05 18:51:04'),
(41, 25, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 0, '2026-05-05 19:01:37'),
(42, 25, 'تقييم جديد', 'حصلت على تقييم 3 نجمة', NULL, NULL, 1, '2026-05-05 19:04:07'),
(43, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1530 ريال للشحنة #31', NULL, NULL, 1, '2026-05-07 06:20:14'),
(44, 41, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 31', NULL, NULL, 0, '2026-05-07 06:20:35'),
(45, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #11 للشحنة #31 بقيمة ١٬٥٣٠ ريال', NULL, NULL, 1, '2026-05-07 06:20:36'),
(46, 41, 'عقد إلكتروني', 'تم إنشاء عقد رقم #11 للشحنة #31 بقيمة ١٬٥٣٠ ريال', NULL, NULL, 0, '2026-05-07 06:20:36'),
(47, 40, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 0, '2026-05-07 06:26:34'),
(48, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1710 ريال للشحنة #32', NULL, NULL, 0, '2026-05-07 06:28:35'),
(49, 41, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 32', NULL, NULL, 0, '2026-05-07 06:36:14'),
(50, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #12 للشحنة #32 بقيمة ١٬٧١٠ ريال', NULL, NULL, 1, '2026-05-07 06:36:14'),
(51, 41, 'عقد إلكتروني', 'تم إنشاء عقد رقم #12 للشحنة #32 بقيمة ١٬٧١٠ ريال', NULL, NULL, 0, '2026-05-07 06:36:14'),
(52, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 4317 ريال للشحنة #34', NULL, NULL, 0, '2026-05-07 08:21:17'),
(53, 41, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 34', NULL, NULL, 0, '2026-05-07 08:21:45'),
(54, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #13 للشحنة #34 بقيمة ٤٬٣١٧ ريال', NULL, NULL, 1, '2026-05-07 08:21:46'),
(55, 41, 'عقد إلكتروني', 'تم إنشاء عقد رقم #13 للشحنة #34 بقيمة ٤٬٣١٧ ريال', NULL, NULL, 0, '2026-05-07 08:21:46'),
(56, 40, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 0, '2026-05-07 08:25:29'),
(57, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1620 ريال للشحنة #35', NULL, NULL, 0, '2026-05-07 12:31:19'),
(58, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 35', NULL, NULL, 0, '2026-05-07 12:31:49'),
(59, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #14 للشحنة #35 بقيمة ١٬٦٢٠ ريال', NULL, NULL, 0, '2026-05-07 12:31:51'),
(60, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #14 للشحنة #35 بقيمة ١٬٦٢٠ ريال', NULL, NULL, 0, '2026-05-07 12:31:51'),
(61, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 300 ريال للشحنة #36', NULL, NULL, 0, '2026-05-11 16:49:41'),
(62, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 36', NULL, NULL, 0, '2026-05-11 16:49:53'),
(63, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #15 للشحنة #36 بقيمة ٣٠٠ ريال', NULL, NULL, 1, '2026-05-11 16:49:55'),
(64, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #15 للشحنة #36 بقيمة ٣٠٠ ريال', NULL, NULL, 0, '2026-05-11 16:49:55'),
(65, 40, 'تقييم جديد', 'حصلت على تقييم 4 نجمة', NULL, NULL, 1, '2026-05-11 16:50:53'),
(66, 24, 'تقييم جديد', 'حصلت على تقييم 3 نجمة', NULL, NULL, 0, '2026-05-11 16:56:43'),
(67, 41, 'تقييم جديد', 'حصلت على تقييم 3 نجمة', NULL, NULL, 0, '2026-05-11 17:07:58'),
(68, 1, 'عرض جديد', 'حصلت على عرض جديد بسعر 585 ريال للشحنة #6', NULL, NULL, 0, '2026-05-11 17:52:33'),
(69, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1530 ريال للشحنة #37', NULL, NULL, 0, '2026-05-11 18:30:32'),
(70, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 37', NULL, NULL, 0, '2026-05-11 18:31:07'),
(71, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #16 للشحنة #37 بقيمة ١٬٥٣٠ ريال', NULL, NULL, 0, '2026-05-11 18:31:10'),
(72, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #16 للشحنة #37 بقيمة ١٬٥٣٠ ريال', NULL, NULL, 0, '2026-05-11 18:31:10'),
(73, 40, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 0, '2026-05-11 18:32:10'),
(74, 24, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 0, '2026-05-11 18:32:58'),
(75, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 2910 ريال للشحنة #38', NULL, NULL, 0, '2026-05-11 20:21:15'),
(76, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 478979 ريال للشحنة #39', NULL, NULL, 0, '2026-05-11 20:22:44'),
(77, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 39', NULL, NULL, 0, '2026-05-11 20:23:31'),
(78, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #17 للشحنة #39 بقيمة ٤٧٨٬٩٧٩ ريال', NULL, NULL, 1, '2026-05-11 20:23:33'),
(79, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #17 للشحنة #39 بقيمة ٤٧٨٬٩٧٩ ريال', NULL, NULL, 0, '2026-05-11 20:23:33'),
(80, 15, 'عرض جديد', 'حصلت على عرض جديد بسعر 1530 ريال للشحنة #41', NULL, NULL, 0, '2026-05-11 21:25:44'),
(81, 40, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', NULL, NULL, 0, '2026-05-12 17:47:41'),
(82, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1620 ⃁ للشحنة #42', NULL, NULL, 1, '2026-05-12 19:01:14'),
(83, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 42', NULL, NULL, 0, '2026-05-12 19:03:29'),
(84, 40, 'عقد إلكتروني', 'تم إنشاء عقد رقم #18 للشحنة #42 بقيمة ١٬٦٢٠ ⃁', NULL, NULL, 1, '2026-05-12 19:03:30'),
(85, 24, 'عقد إلكتروني', 'تم إنشاء عقد رقم #18 للشحنة #42 بقيمة ١٬٦٢٠ ⃁', NULL, NULL, 0, '2026-05-12 19:03:30'),
(86, 40, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', 42, NULL, 1, '2026-05-12 19:18:12'),
(87, 24, 'تقييم جديد', 'حصلت على تقييم 3 نجمة', 42, NULL, 0, '2026-05-12 19:20:08'),
(88, 47, 'عرض جديد', 'حصلت على عرض جديد بسعر 1300 ⃁ للشحنة #43', 43, 38, 0, '2026-05-12 19:32:28'),
(89, 46, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 43', 43, 38, 0, '2026-05-12 19:33:18'),
(90, 47, 'عقد إلكتروني', 'تم إنشاء عقد رقم #19 للشحنة #43 بقيمة ١٬٣٠٠ ⃁', 43, 38, 1, '2026-05-12 19:33:19'),
(91, 46, 'عقد إلكتروني', 'تم إنشاء عقد رقم #19 للشحنة #43 بقيمة ١٬٣٠٠ ⃁', 43, 38, 0, '2026-05-12 19:33:19'),
(92, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 3000 ⃁ للشحنة #45', 45, 39, 0, '2026-05-12 20:09:53'),
(93, 24, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 45', 45, 39, 0, '2026-05-12 20:10:03'),
(94, 40, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #45 بقيمة ٣٬٠٠٠ ⃁', 45, 39, 1, '2026-05-12 20:10:04'),
(95, 24, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #45 بقيمة ٣٬٠٠٠ ⃁', 45, 39, 0, '2026-05-12 20:10:04'),
(96, 40, 'تقييم جديد', 'حصلت على تقييم 1 نجمة', 45, NULL, 0, '2026-05-12 20:23:10'),
(97, 24, 'تقييم جديد', 'حصلت على تقييم 1 نجمة', 45, NULL, 0, '2026-05-12 20:23:27'),
(98, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1620 ⃁ للشحنة #46', 46, 40, 0, '2026-05-12 20:27:49'),
(99, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1500 ⃁ للشحنة #46', 46, 41, 0, '2026-05-12 20:28:20'),
(100, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1300 ⃁ للشحنة #46', 46, 42, 1, '2026-05-12 20:29:26'),
(101, 46, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 46', 46, 40, 0, '2026-05-12 20:43:06'),
(102, 24, 'تم رفض عرضك', 'تم اختيار عرض آخر للشحنة رقم 46', 46, 40, 0, '2026-05-12 20:43:06'),
(103, 41, 'تم رفض عرضك', 'تم اختيار عرض آخر للشحنة رقم 46', 46, 40, 0, '2026-05-12 20:43:06'),
(104, 40, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #46 بقيمة ١٬٦٢٠ ⃁', 46, 40, 0, '2026-05-12 20:43:08'),
(105, 46, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #46 بقيمة ١٬٦٢٠ ⃁', 46, 40, 0, '2026-05-12 20:43:08'),
(106, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1710 ⃁ للشحنة #47', 47, 43, 0, '2026-05-12 20:58:43'),
(107, 41, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 47', 47, 43, 0, '2026-05-12 20:58:53'),
(108, 40, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #47 بقيمة ١٬٧١٠ ⃁', 47, 43, 0, '2026-05-12 20:58:54'),
(109, 41, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #47 بقيمة ١٬٧١٠ ⃁', 47, 43, 0, '2026-05-12 20:58:54'),
(110, 47, 'عرض جديد', 'حصلت على عرض جديد بسعر 4100 ⃁ للشحنة #44', 44, 44, 0, '2026-05-13 00:40:49'),
(111, 25, 'تقييم جديد', 'حصلت على تقييم 3 نجمة', 25, NULL, 0, '2026-05-13 20:12:03'),
(112, 41, 'تقييم جديد', 'حصلت على تقييم 3 نجمة', 47, NULL, 0, '2026-05-13 20:27:19'),
(113, 1, 'عرض جديد', 'حصلت على عرض جديد بسعر 4950 ⃁ للشحنة #8', 8, 45, 0, '2026-05-14 03:35:22'),
(114, 1, 'عرض جديد', 'حصلت على عرض جديد بسعر 1100 ⃁ للشحنة #4', 4, 46, 0, '2026-05-14 03:35:34'),
(115, 1, 'عرض جديد', 'حصلت على عرض جديد بسعر 900 ⃁ للشحنة #2', 2, 47, 0, '2026-05-14 03:51:43'),
(116, 1, 'عرض جديد', 'حصلت على عرض جديد بسعر 3780 ⃁ للشحنة #5', 5, 48, 0, '2026-05-14 04:00:25'),
(117, 1, 'عرض جديد', 'حصلت على عرض جديد بسعر 4100 ⃁ للشحنة #8', 8, 49, 0, '2026-05-14 04:02:08'),
(118, 1, 'عرض جديد', 'حصلت على عرض جديد بسعر 3500 ⃁ للشحنة #5', 5, 50, 0, '2026-05-14 04:04:37'),
(119, 52, 'عرض جديد', 'حصلت على عرض جديد بسعر 1530 ⃁ للشحنة #48', 48, 51, 0, '2026-05-14 08:22:22'),
(120, 55, 'تم قبول عرضك', 'تم قبول عرضك للشحنة رقم 48', 48, 51, 0, '2026-05-14 08:22:49'),
(121, 52, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #48 بقيمة ١٬٥٣٠ ⃁', 48, 51, 0, '2026-05-14 08:22:50'),
(122, 55, 'عقد إلكتروني', 'تم إنشاء عقد للشحنة #48 بقيمة ١٬٥٣٠ ⃁', 48, 51, 0, '2026-05-14 08:22:50'),
(123, 52, 'تقييم جديد', 'حصلت على تقييم 4 نجمة', 48, NULL, 0, '2026-05-14 08:26:21'),
(124, 55, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', 48, NULL, 0, '2026-05-14 08:26:36'),
(125, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1260 ⃁ للشحنة #49', 49, 52, 0, '2026-05-14 21:41:10'),
(126, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1200 ⃁ للشحنة #49', 49, 53, 0, '2026-05-14 21:41:43'),
(127, 40, 'عرض جديد', 'حصلت على عرض جديد بسعر 1540 ⃁ للشحنة #49', 49, 54, 0, '2026-05-14 21:44:41'),
(128, 24, 'تقييم جديد', 'حصلت على تقييم 5 نجمة', 39, NULL, 0, '2026-05-14 21:59:15'),
(129, 41, 'تقييم جديد', 'حصلت على تقييم 1 نجمة', 32, NULL, 0, '2026-05-14 21:59:48');

-- --------------------------------------------------------

--
-- بنية الجدول `password_reset_tokens`
--

CREATE TABLE `password_reset_tokens` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `token_hash` char(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `requested_ip` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `password_reset_tokens`
--

INSERT INTO `password_reset_tokens` (`id`, `user_id`, `token_hash`, `expires_at`, `used_at`, `requested_ip`, `user_agent`, `created_at`) VALUES
(1, 24, '8390b6bb8bf6627b1be849928d1b7e94ba2ebc63bedc48ae0a04c397ef3f5db3', '2026-05-11 19:13:38', NULL, '::ffff:127.0.0.1', 'Dart/3.11 (dart:io)', '2026-05-11 18:13:38'),
(2, 45, '146448d3365cb61f141a4f8b7106a657fb46c245cbba22115b7c15a076e979df', '2026-05-11 19:15:04', '2026-05-13 04:44:28', '::ffff:127.0.0.1', 'Dart/3.11 (dart:io)', '2026-05-11 18:15:04'),
(3, 45, 'df5837a2289fdfacdde15e9bc7f4a0a0367d602a06f535979fe9b92234bbb198', '2026-05-13 01:49:28', '2026-05-13 22:42:23', '::ffff:127.0.0.1', 'Dart/3.11 (dart:io)', '2026-05-13 01:44:28'),
(15, 45, 'ce8685a9fb199f111820ef3c15c113fb4ee8bd2862765f36789f771818e76878', '2026-05-13 22:47:23', NULL, '::ffff:127.0.0.1', 'Dart/3.11 (dart:io)', '2026-05-13 19:42:23');

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

--
-- إرجاع أو استيراد بيانات الجدول `ratings`
--

INSERT INTO `ratings` (`id`, `shipment_id`, `rater_id`, `rated_id`, `stars`, `comment`, `created_at`) VALUES
(1, 17, 16, 15, 5, 'asdasasd', '2026-04-30 23:51:46'),
(2, 18, 24, 25, 5, 'ASDSADSADASD', '2026-05-01 00:14:44'),
(3, 19, 26, 27, 1, 'سرقتي', '2026-05-01 00:57:37'),
(4, 20, 24, 28, 5, '', '2026-05-02 13:14:28'),
(5, 28, 24, 25, 2, '', '2026-05-05 00:28:29'),
(6, 29, 24, 25, 5, 'rtytryryrty', '2026-05-05 19:01:37'),
(7, 30, 24, 25, 3, '', '2026-05-05 19:04:07'),
(8, 31, 41, 40, 5, '', '2026-05-07 06:26:34'),
(9, 34, 41, 40, 5, '', '2026-05-07 08:25:29'),
(10, 36, 24, 40, 4, NULL, '2026-05-11 16:50:53'),
(11, 36, 40, 24, 3, NULL, '2026-05-11 16:56:43'),
(12, 34, 40, 41, 3, NULL, '2026-05-11 17:07:58'),
(13, 37, 24, 40, 5, NULL, '2026-05-11 18:32:10'),
(14, 37, 40, 24, 5, NULL, '2026-05-11 18:32:58'),
(15, 39, 24, 40, 5, NULL, '2026-05-12 17:47:41'),
(16, 42, 24, 40, 5, NULL, '2026-05-12 19:18:12'),
(17, 42, 40, 24, 3, NULL, '2026-05-12 19:20:08'),
(18, 45, 24, 40, 1, NULL, '2026-05-12 20:23:10'),
(19, 45, 40, 24, 1, NULL, '2026-05-12 20:23:27'),
(20, 25, 24, 25, 3, NULL, '2026-05-13 20:12:03'),
(21, 47, 40, 41, 3, 'sdfdsfdsfsdf', '2026-05-13 20:27:19'),
(22, 48, 55, 52, 4, NULL, '2026-05-14 08:26:21'),
(23, 48, 52, 55, 5, NULL, '2026-05-14 08:26:36'),
(24, 39, 40, 24, 5, NULL, '2026-05-14 21:59:15'),
(25, 32, 40, 41, 1, NULL, '2026-05-14 21:59:48');

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
  `penalty_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `late_penalty_push_sent` tinyint(1) NOT NULL DEFAULT 0,
  `status` enum('pending','bidding','assigned','at_pickup','en_route','at_dropoff','delivered','cancelled') DEFAULT 'pending',
  `expected_delivery_date` datetime NOT NULL,
  `final_delivery_date` datetime DEFAULT NULL,
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

INSERT INTO `shipments` (`id`, `shipper_id`, `driver_id`, `weight_kg`, `cargo_description`, `pickup_address`, `pickup_lat`, `pickup_lng`, `dropoff_address`, `dropoff_lat`, `dropoff_lng`, `base_price`, `final_price`, `penalty_amount`, `late_penalty_push_sent`, `status`, `expected_delivery_date`, `final_delivery_date`, `actual_delivery_date`, `created_at`, `period`, `special_instructions`, `auction_duration_hours`, `auction_end_time`) VALUES
(1, 4, NULL, 8.50, '????? ????', '??????', NULL, NULL, '???', NULL, NULL, 1400.00, NULL, 0.00, 0, 'bidding', '2025-05-01 00:00:00', '2025-05-01 00:00:00', NULL, '2026-03-31 20:34:30', NULL, NULL, 24, NULL),
(2, 1, NULL, 2.00, 'مفروشات', 'مكة', NULL, NULL, 'جدة', NULL, NULL, 1000.00, NULL, 0.00, 0, 'bidding', '2026-04-10 09:20:00', '2026-04-10 09:20:00', NULL, '2026-04-09 07:14:06', NULL, NULL, 24, NULL),
(3, 1, NULL, 2.00, 'مفروشات', 'مكة', NULL, NULL, 'جدة', NULL, NULL, 1000.00, NULL, 0.00, 0, 'bidding', '2026-04-10 09:20:00', '2026-04-10 09:20:00', NULL, '2026-04-09 07:14:15', NULL, NULL, 24, NULL),
(4, 1, NULL, 2.00, 'مفروشات', 'مكة', NULL, NULL, 'جدة', NULL, NULL, 1000.00, NULL, 0.00, 0, 'bidding', '2026-04-10 09:20:00', '2026-04-10 09:20:00', NULL, '2026-04-09 07:14:22', NULL, NULL, 24, NULL),
(5, 1, NULL, 2.00, 'مواد بناء', 'الرياض', NULL, NULL, 'جدة', NULL, NULL, 4200.00, NULL, 0.00, 0, 'bidding', '2026-04-11 08:00:00', '2026-04-11 08:00:00', NULL, '2026-04-09 07:56:17', NULL, NULL, 24, NULL),
(6, 1, NULL, 0.40, 'معدات', 'سش', NULL, NULL, 'طنطا', NULL, NULL, 650.00, NULL, 0.00, 0, 'bidding', '2026-04-12 12:00:00', '2026-04-12 12:00:00', NULL, '2026-04-09 08:15:00', NULL, NULL, 24, NULL),
(7, 1, NULL, 2.00, 'مفروشات', 'الرياض', NULL, NULL, 'مكة', NULL, NULL, 4500.00, NULL, 0.00, 0, 'bidding', '2026-04-13 15:10:00', '2026-04-13 15:10:00', NULL, '2026-04-09 10:09:39', NULL, NULL, 24, NULL),
(8, 1, NULL, 2.00, 'مفروشات', 'الرياض', NULL, NULL, 'مكة', NULL, NULL, 4500.00, NULL, 0.00, 0, 'bidding', '2026-04-13 15:10:00', '2026-04-13 15:10:00', NULL, '2026-04-09 10:10:32', NULL, NULL, 24, NULL),
(9, 9, 10, 2.30, 'ادوات بناء', 'مكة', NULL, NULL, 'الرياض', NULL, NULL, 3000.00, NULL, 0.00, 0, 'en_route', '2026-04-28 00:00:00', '2026-04-28 00:00:00', NULL, '2026-04-15 18:01:42', 'morning', NULL, 24, NULL),
(10, 9, NULL, 1.60, 'معدات', 'الدمام', NULL, NULL, 'الرياض', NULL, NULL, 2600.00, NULL, 0.00, 0, 'bidding', '2026-04-23 00:00:00', '2026-04-23 00:00:00', NULL, '2026-04-15 19:59:56', 'evening', NULL, 24, NULL),
(11, 9, 10, 3.40, 'حديد', 'مكة', NULL, NULL, 'الرياض', NULL, NULL, 4600.00, NULL, 0.00, 0, 'at_dropoff', '2026-04-30 00:00:00', '2026-04-30 00:00:00', NULL, '2026-04-20 19:28:54', 'morning', 'يجب ن يكون في الشاحنة حواجز لتجنب تحرك الحديد اثناء النقل', 24, NULL),
(12, 9, 10, 0.80, 'اواني منزلية', 'الرياض', NULL, NULL, 'الدمام', NULL, NULL, 2300.00, NULL, 0.00, 0, 'at_dropoff', '2026-04-24 00:00:00', '2026-04-24 00:00:00', NULL, '2026-04-21 21:20:15', 'evening', 'الرجاء التعامل معها بحذر شديد', 24, NULL),
(13, 9, 10, 6.50, 'سيارات', 'الرياض', 24.74500655, 46.68339261, 'الاحساء', 24.66431361, 46.67647710, 4500.00, NULL, 0.00, 0, 'at_dropoff', '2026-04-29 00:00:00', '2026-04-29 00:00:00', NULL, '2026-04-21 21:50:03', 'evening', 'يجب ان تكون الشاحنة تسمح بحمل السيارات وتكون دورين', 24, NULL),
(14, 9, NULL, 4.00, '4', 'k', 24.73418221, 46.67152345, 'm', 24.71404554, 46.67530000, 4.00, NULL, 0.00, 0, 'bidding', '2026-04-25 00:00:00', '2026-04-25 00:00:00', NULL, '2026-04-21 23:13:22', 'morning', '4', 24, NULL),
(15, 15, 16, 23.00, 'حديد', 'الرياض', 24.71360000, 46.67530000, 'جدة', 24.70667850, 46.67283160, 1200.00, NULL, 0.00, 0, 'delivered', '2026-04-30 00:00:00', '2026-04-30 00:00:00', '2026-04-30 00:36:06', '2026-04-29 19:13:37', 'evening', NULL, 24, '2026-04-30 22:13:37'),
(16, 15, 16, 12.00, '212', 'اااتاا', 24.71360000, 46.67530000, 'للبل', 24.71360000, 46.67530000, 1233.00, NULL, 0.00, 0, 'delivered', '2026-05-28 00:00:00', '2026-05-28 00:00:00', '2026-04-30 00:40:56', '2026-04-29 21:39:24', 'evening', NULL, 12, '2026-04-30 12:39:24'),
(17, 15, 16, 23.00, 'sdfds', 'tyrtyr', 24.71360000, 46.67530000, 'hfghgfh', 24.71360000, 46.67530000, 2000.00, NULL, 0.00, 0, 'delivered', '2026-05-29 00:00:00', '2026-05-29 00:00:00', '2026-04-30 02:02:12', '2026-04-29 22:55:28', 'morning', NULL, 2, '2026-04-30 03:55:28'),
(18, 25, 24, 23.00, 'حديد', 'الرياض', 24.71112101, 46.66706065, 'جدة', 24.72678137, 46.63927794, 1300.00, NULL, 0.00, 0, 'delivered', '2026-05-30 00:00:00', '2026-05-30 00:00:00', '2026-05-01 03:14:09', '2026-04-30 23:59:32', 'evening', 'الحذر', 2, '2026-05-01 04:59:32'),
(19, 27, 26, 17.00, 'حديد', 'الرياض', 24.70172400, 46.68644290, 'جدة', 24.71360000, 46.67530000, 1400.00, NULL, 0.00, 0, 'delivered', '2026-05-30 00:00:00', '2026-05-30 00:00:00', '2026-05-01 03:55:06', '2026-05-01 00:48:59', 'evening', NULL, 2, '2026-05-01 05:48:59'),
(20, 28, 24, 34.00, 'sdfdsf', 'awdasd', 24.71495118, 46.67448472, 'asdsad', 24.71360000, 46.67530000, 1000.00, NULL, 0.00, 0, 'delivered', '2026-05-05 00:00:00', '2026-05-05 00:00:00', '2026-05-02 16:13:06', '2026-05-02 13:06:14', 'evening', 'dsfds', 2, '2026-05-02 18:06:14'),
(21, 28, 24, 12321.00, '1231', 'sefsefsd', 24.74574390, 46.66378494, 'sdfdsfdsfsdf', 24.71360000, 46.67530000, 213213.00, NULL, 0.00, 0, 'at_pickup', '2026-05-29 00:00:00', '2026-05-29 00:00:00', NULL, '2026-05-02 14:01:01', 'morning', 'asda', 2, '2026-05-02 19:01:01'),
(22, 28, 24, 234342.00, '2343242', 'ESFS', 24.71360000, 46.67530000, 'SDFSFDS', 24.71360000, 46.67530000, 324324.00, 275675.00, 0.00, 0, 'delivered', '2026-05-27 00:00:00', '2026-05-27 00:00:00', '2026-05-13 23:10:35', '2026-05-02 14:20:05', 'evening', '34324', 2, '2026-05-02 19:20:05'),
(23, 28, NULL, 2.00, 'حديد', 'الرياض', 24.74163013, 46.67196905, 'جدة', 24.60696051, 46.64215101, 350.00, NULL, 0.00, 0, 'bidding', '2026-05-29 00:00:00', '2026-05-29 00:00:00', NULL, '2026-05-02 19:13:14', 'evening', 'انتبه', 2, '2026-05-03 00:13:14'),
(24, 25, 24, 2.00, 'طول/رمل', 'الرياض', 24.64768436, 46.71014577, 'جدة', 21.53899046, 39.19900023, 800.00, NULL, 0.00, 0, 'assigned', '2026-05-29 00:00:00', '2026-05-29 00:00:00', NULL, '2026-05-04 23:34:53', 'evening', NULL, 2, '2026-05-05 04:34:53'),
(25, 25, 24, 234324.00, '324324', 'sdfsdf', 24.71360000, 46.67530000, 'sdfdsf', 24.71360000, 46.67530000, 324324.00, 291892.00, 0.00, 0, 'delivered', '2026-05-29 00:00:00', '2026-05-29 00:00:00', '2026-05-13 23:11:48', '2026-05-04 23:59:32', 'evening', NULL, 2, '2026-05-05 04:59:32'),
(26, 25, 24, 5.00, 'fghg', 'dawda', 24.71360000, 46.67530000, 'wadwad', 24.71360000, 46.67530000, 4545.00, 4091.00, 0.00, 0, 'delivered', '2026-05-28 00:00:00', '2026-05-28 00:00:00', '2026-05-13 22:55:25', '2026-05-05 00:09:39', 'evening', NULL, 2, '2026-05-05 05:09:39'),
(27, 25, 24, 55.00, '55', 'tht', 24.71360000, 46.67530000, 'fghgfh', 24.71360000, 46.67530000, 55.00, 50.00, 0.00, 0, 'delivered', '2026-05-29 00:00:00', '2026-05-29 00:00:00', '2026-05-13 23:02:58', '2026-05-05 00:11:31', 'evening', NULL, 12, '2026-05-05 15:11:31'),
(28, 25, 24, 44.00, '44', 'sdfsd', 24.71360000, 46.67530000, 'dsfds', 24.71360000, 46.67530000, 454.00, 409.00, 0.00, 0, 'delivered', '2026-05-19 00:00:00', '2026-05-19 00:00:00', '2026-05-05 03:28:02', '2026-05-05 00:19:41', 'evening', NULL, 6, '2026-05-05 09:19:41'),
(29, 25, 24, 444.00, '44', 'الرياض', 24.71360000, 46.67530000, 'القصيم', 24.71360000, 46.67530000, 444.00, 400.00, 0.00, 0, 'delivered', '2026-05-28 00:00:00', '2026-05-28 00:00:00', '2026-05-05 21:49:53', '2026-05-05 00:29:48', 'evening', NULL, 2, '2026-05-05 05:29:48'),
(30, 25, 24, 22.00, '22', 'sadsad', 24.71360000, 46.67530000, 'asdsad', 24.71360000, 46.67530000, 22.00, 20.00, 0.00, 0, 'delivered', '2026-05-22 00:00:00', '2026-05-22 00:00:00', '2026-05-05 22:03:58', '2026-05-05 18:50:28', 'evening', NULL, 2, '2026-05-05 23:50:28'),
(31, 40, 41, 22.00, 'حديد', 'الرياض', 24.71067670, 46.67025018, 'جدة', 21.19119062, 39.27058471, 1700.00, 1530.00, 0.00, 0, 'delivered', '2026-05-12 00:00:00', '2026-05-12 00:00:00', '2026-05-07 09:26:26', '2026-05-07 06:19:39', 'evening', NULL, 6, '2026-05-07 15:19:39'),
(32, 40, 41, 12.00, 'حديد', 'الرياض', 24.71360000, 46.67530000, 'جدة', 24.71360000, 46.67530000, 1900.00, 1710.00, 0.00, 0, 'delivered', '2026-05-15 00:00:00', '2026-05-15 00:00:00', '2026-05-12 23:44:54', '2026-05-07 06:28:08', 'evening', 'انتبه', 6, '2026-05-07 15:28:08'),
(33, 40, NULL, 23.00, 'حديد', 'الرياض', 24.70413685, 46.66488215, 'جدة', 24.71360000, 46.67530000, 1.00, NULL, 0.00, 0, 'bidding', '2026-05-09 00:00:00', '2026-05-09 00:00:00', NULL, '2026-05-07 08:19:16', 'evening', NULL, 2, '2026-05-07 13:19:16'),
(34, 40, 41, 4.00, 'gfhfgh', 'sdsad', 24.71360000, 46.67530000, 'sadsa', 24.71360000, 46.67530000, 4544.00, 4317.00, 0.00, 0, 'delivered', '2026-05-09 00:00:00', '2026-05-09 00:00:00', '2026-05-07 11:25:19', '2026-05-07 08:20:29', 'evening', NULL, 2, '2026-05-07 13:20:29'),
(35, 40, 24, 3.00, 'حديد', 'الرياض', 24.80752711, 46.62556235, 'جدة', 21.24350532, 39.30473838, 1800.00, NULL, 0.00, 0, 'at_dropoff', '2026-05-15 00:00:00', '2026-05-15 00:00:00', NULL, '2026-05-07 12:30:51', 'evening', NULL, 12, '2026-05-08 03:30:51'),
(36, 40, 24, 333.00, '33', 'sdfdsf', 24.71360000, 46.67530000, 'dsfdsf', 24.71360000, 46.67530000, 333.00, 300.00, 0.00, 0, 'delivered', '2026-05-28 00:00:00', '2026-05-28 00:00:00', '2026-05-11 19:50:40', '2026-05-11 16:49:26', 'evening', 'dgdfgdf', 12, '2026-05-12 07:49:26'),
(37, 40, 24, 12.00, 'sasdf', 'sdsdfs', 24.71360000, 46.67530000, 'dsfdsfdsf', 24.71360000, 46.67530000, 1700.00, 1530.00, 0.00, 0, 'delivered', '2026-05-28 00:00:00', '2026-05-28 00:00:00', '2026-05-11 21:32:00', '2026-05-11 18:29:13', 'evening', 'dsfdsf', 2, '2026-05-11 23:29:13'),
(38, 40, NULL, 23.00, 'dsfsdf', 'sdfds', 24.71360000, 46.67530000, 'dsfsf', 24.71360000, 46.67530000, 3233.00, NULL, 0.00, 0, 'bidding', '2026-05-13 00:00:00', '2026-05-13 00:00:00', NULL, '2026-05-11 20:19:53', 'morning', 'sdfsdfsd', 24, '2026-05-12 23:19:53'),
(39, 40, 24, 34.00, '345fg', 'rtert', 24.71360000, 46.67530000, 'retreter', 24.71360000, 46.67530000, 435435.00, 478979.00, 0.00, 0, 'delivered', '2026-05-20 00:00:00', '2026-05-20 00:00:00', '2026-05-12 20:47:33', '2026-05-11 20:22:23', 'morning', 'dfgfdg', 24, '2026-05-12 23:22:23'),
(40, 15, NULL, 20.00, 'حديد', 'الرياض', 24.78683209, 46.68680561, 'مكة', 21.37333498, 39.34473840, 1200.00, NULL, 0.00, 0, 'bidding', '2026-05-14 00:00:00', '2026-05-14 00:00:00', NULL, '2026-05-11 21:18:31', 'evening', NULL, 2, '2026-05-12 02:18:31'),
(41, 15, NULL, 23.00, '2332', 'rddffdf', 58.18049755, 25.11050441, 'ماينمار', 24.71360000, 46.67530000, 1700.00, NULL, 0.00, 0, 'bidding', '2026-05-15 00:00:00', '2026-05-15 00:00:00', NULL, '2026-05-11 21:21:14', 'evening', '233', 2, '2026-05-12 02:21:14'),
(42, 40, 24, 10.00, 'حديد', 'الرياض', 24.70085070, 46.70226311, 'جدة', 21.34187633, 39.29117069, 1800.00, 1620.00, 0.00, 0, 'delivered', '2026-05-14 00:00:00', '2026-05-14 00:00:00', '2026-05-12 22:18:05', '2026-05-12 19:00:37', 'evening', 'إذا حصلت ضروري اتصل عل ذا الرقم٠٥٤٠٧٠٤٤١٩', 2, '2026-05-13 00:00:37'),
(43, 47, 46, 15.00, 'مواد بناء', 'الرياض', 24.71968084, 46.67680204, 'جدة', 21.49581103, 39.18578695, 1900.00, 1300.00, 0.00, 0, 'delivered', '2026-05-20 00:00:00', '2026-05-20 00:00:00', '2026-05-15 01:13:31', '2026-05-12 19:31:36', 'evening', 'اتصل علي إذا وصلت', 2, '2026-05-13 00:31:36'),
(44, 47, NULL, 44.00, '454', 'cbvcvb', 24.71360000, 46.67530000, 'vcbvcbcv', 24.70603620, 46.66757580, 4555.00, NULL, 0.00, 0, 'bidding', '2026-05-26 00:00:00', '2026-05-26 00:00:00', NULL, '2026-05-12 19:34:36', 'evening', '4545', 6, '2026-05-13 04:34:36'),
(45, 40, 24, 33.00, 'dfgdfg', 'fegdfgd', 24.71360000, 46.67530000, 'dfgfdgfd', 24.68187603, 46.65434357, 3333.00, 3000.00, 0.00, 0, 'delivered', '2026-05-21 00:00:00', '2026-05-21 00:00:00', '2026-05-12 23:22:58', '2026-05-12 20:09:41', 'morning', 'fdgdfg', 6, '2026-05-13 05:09:41'),
(46, 40, 46, 12.00, 'حديد', 'المدينة', 27.02964669, 38.60076417, 'جدة', 24.71360000, 46.67530000, 1800.00, 1620.00, 0.00, 0, 'delivered', '2026-05-14 00:00:00', '2026-05-14 00:00:00', '2026-05-15 01:10:50', '2026-05-12 20:27:37', 'evening', NULL, 24, '2026-05-13 23:27:37'),
(47, 40, 41, 12.00, 'شس', 'الرياض', 24.71360000, 46.67530000, 'جدة', 24.74883622, 46.67867623, 1900.00, 1710.00, 0.00, 0, 'delivered', '2026-05-19 00:00:00', '2026-05-19 00:00:00', '2026-05-13 00:01:10', '2026-05-12 20:58:11', 'evening', NULL, 12, '2026-05-13 11:58:11'),
(48, 52, 55, 2.00, 'حديد', 'الرياض', 24.71360000, 46.67530000, 'جدة', 21.22733329, 39.77503726, 1700.00, 1530.00, 0.00, 0, 'delivered', '2026-05-15 00:00:00', '2026-05-15 00:00:00', '2026-05-14 11:26:12', '2026-05-14 08:20:28', 'evening', 'انتبه', 2, '2026-05-14 13:20:28'),
(49, 40, NULL, 6.00, 'حديد', 'الرياض', 24.71360000, 46.67530000, 'جدة', 21.35617814, 39.14858033, 1400.00, NULL, 0.00, 0, 'bidding', '2026-05-17 00:00:00', '2026-05-17 00:00:00', NULL, '2026-05-14 21:40:15', 'evening', NULL, 6, '2026-05-15 06:40:15');

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
(19, 16, 'delivered', NULL, NULL, 'epod/1777498856394-IMG_20260423_140242.jpg', '2026-04-29 21:40:56'),
(20, 17, 'at_pickup', NULL, NULL, NULL, '2026-04-29 23:01:46'),
(21, 17, 'en_route', NULL, NULL, NULL, '2026-04-29 23:01:50'),
(22, 17, 'at_dropoff', NULL, NULL, NULL, '2026-04-29 23:01:55'),
(23, 17, 'delivered', NULL, NULL, 'epod/1777503732883-IMG_20260423_140242.jpg', '2026-04-29 23:02:12'),
(24, 18, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-01 00:05:54'),
(25, 18, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-01 00:05:56'),
(26, 18, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-01 00:06:14'),
(27, 18, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-01 00:06:33'),
(28, 18, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-01 00:07:09'),
(29, 18, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-01 00:07:11'),
(30, 18, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-01 00:12:58'),
(31, 18, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-01 00:13:12'),
(32, 18, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-01 00:13:45'),
(33, 18, 'delivered', NULL, NULL, 'epod/1777594448988-IMG_20260423_140242.jpg', '2026-05-01 00:14:09'),
(34, 19, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-01 00:51:07'),
(35, 19, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-01 00:51:07'),
(36, 19, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-01 00:51:09'),
(37, 19, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-01 00:51:37'),
(38, 19, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-01 00:51:39'),
(39, 19, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-01 00:52:23'),
(40, 19, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-01 00:54:57'),
(41, 19, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-01 00:54:57'),
(42, 19, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-01 00:54:57'),
(43, 19, 'delivered', NULL, NULL, 'epod/1777596905992-IMG_20260501_034410.jpg', '2026-05-01 00:55:06'),
(44, 20, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-02 13:10:21'),
(45, 20, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-02 13:10:21'),
(46, 20, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-02 13:11:34'),
(47, 20, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-02 13:11:34'),
(48, 20, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-02 13:11:43'),
(49, 20, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-02 13:12:16'),
(50, 20, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-02 13:12:17'),
(51, 20, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-02 13:12:19'),
(52, 20, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-02 13:12:50'),
(53, 20, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-02 13:13:02'),
(54, 20, 'delivered', NULL, NULL, 'epod/1777727586936-IMG_20260501_034410.jpg', '2026-05-02 13:13:06'),
(55, 27, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 00:13:28'),
(56, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:13:28'),
(57, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:13:58'),
(58, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:14:07'),
(59, 21, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 00:14:19'),
(60, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:14:49'),
(61, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:14:59'),
(62, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:15:15'),
(63, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:15:55'),
(64, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:16:35'),
(65, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:17:10'),
(66, 25, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 00:17:22'),
(67, 22, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 00:17:24'),
(68, 26, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 00:17:32'),
(69, 22, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 00:18:08'),
(70, 28, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 00:26:52'),
(71, 28, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:26:54'),
(72, 28, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 00:27:03'),
(73, 28, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-05 00:27:23'),
(74, 28, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-05 00:27:32'),
(75, 28, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-05 00:27:53'),
(76, 28, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-05 00:28:02'),
(77, 28, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1777940882857-IMG_20260501_034410.jpg', '2026-05-05 00:28:02'),
(78, 29, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 18:49:36'),
(79, 29, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 18:49:36'),
(80, 29, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 18:49:36'),
(81, 29, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-05 18:49:38'),
(82, 29, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-05 18:49:44'),
(83, 29, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-05 18:49:44'),
(84, 29, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-05 18:49:46'),
(85, 29, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778006993080-IMG_20260503_021356.jpg', '2026-05-05 18:49:53'),
(86, 30, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 19:01:17'),
(87, 26, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 19:01:18'),
(88, 30, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 19:03:35'),
(89, 30, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 19:03:35'),
(90, 30, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 19:03:36'),
(91, 30, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-05 19:03:39'),
(92, 30, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-05 19:03:45'),
(93, 30, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-05 19:03:46'),
(94, 30, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-05 19:03:55'),
(95, 30, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778007838401-IMG_20260503_021356.jpg', '2026-05-05 19:03:58'),
(96, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 19:09:57'),
(97, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 19:09:58'),
(98, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 19:10:09'),
(99, 25, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-05 19:10:19'),
(100, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-05 19:11:00'),
(101, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 06:11:05'),
(102, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 06:11:19'),
(103, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 06:11:29'),
(104, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 06:12:07'),
(105, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 06:12:47'),
(106, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 06:13:27'),
(107, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 06:14:07'),
(108, 31, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 06:25:43'),
(109, 31, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 06:25:43'),
(110, 31, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 06:25:52'),
(111, 31, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 06:26:13'),
(112, 31, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-07 06:26:18'),
(113, 31, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778135186758-IMG_20260501_034410.jpg', '2026-05-07 06:26:26'),
(114, 32, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 07:32:12'),
(115, 32, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 07:32:52'),
(116, 32, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 07:33:32'),
(117, 32, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 07:38:34'),
(118, 32, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 07:39:09'),
(119, 32, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 07:39:36'),
(120, 32, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 07:39:45'),
(121, 32, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 08:08:03'),
(122, 32, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 08:12:51'),
(123, 32, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 08:13:08'),
(124, 34, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 08:22:56'),
(125, 34, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 08:23:28'),
(126, 34, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 08:23:28'),
(127, 34, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 08:23:37'),
(128, 34, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 08:24:30'),
(129, 34, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 08:24:30'),
(130, 34, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 08:24:39'),
(131, 34, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-07 08:25:00'),
(132, 34, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-07 08:25:03'),
(133, 34, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778142319359-IMG_20260501_034410.jpg', '2026-05-07 08:25:19'),
(134, 27, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 12:26:39'),
(135, 27, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 12:26:39'),
(136, 27, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 12:26:39'),
(137, 27, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-07 12:26:41'),
(138, 27, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-07 12:26:52'),
(139, 35, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 12:32:02'),
(140, 35, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-07 12:32:44'),
(141, 35, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 12:32:50'),
(142, 35, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-07 12:32:59'),
(143, 35, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 12:33:20'),
(144, 35, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 12:33:29'),
(145, 35, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-07 12:34:07'),
(146, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-07 12:34:37'),
(147, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-07 12:34:46'),
(148, 36, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-11 16:50:25'),
(149, 36, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 16:50:25'),
(150, 36, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 16:50:25'),
(151, 36, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 16:50:26'),
(152, 36, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 16:50:27'),
(153, 36, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 16:50:28'),
(154, 36, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 16:50:28'),
(155, 36, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778518240384-IMG_20260501_034410.jpg', '2026-05-11 16:50:40'),
(156, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 16:53:03'),
(157, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 17:43:57'),
(158, 22, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:10'),
(159, 22, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:10'),
(160, 22, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:11'),
(161, 22, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:12'),
(162, 22, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:19'),
(163, 22, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:19'),
(164, 22, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:22'),
(165, 27, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 17:44:31'),
(166, 37, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-11 18:31:36'),
(167, 37, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 18:31:36'),
(168, 37, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 18:31:38'),
(169, 37, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 18:31:39'),
(170, 37, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 18:31:45'),
(171, 37, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 18:31:45'),
(172, 37, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 18:31:55'),
(173, 37, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778524320099-9887398b-24ed-46e7-8047-c5591a13044c-IMG_20260501_034410.jpg', '2026-05-11 18:32:00'),
(174, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 18:38:44'),
(175, 39, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-11 20:24:07'),
(176, 39, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 20:24:07'),
(177, 39, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-11 20:24:08'),
(178, 39, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 20:24:09'),
(179, 39, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-11 20:24:12'),
(180, 39, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 20:24:38'),
(181, 39, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 20:24:45'),
(182, 39, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-11 22:25:44'),
(183, 25, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-11 22:26:26'),
(184, 39, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 04:54:35'),
(185, 39, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 05:56:27'),
(186, 27, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 05:56:36'),
(187, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 05:56:47'),
(188, 39, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 17:47:29'),
(189, 39, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778608053924-852fd245-5206-4beb-a084-001d7a06946e-IMG_20260501_034410.jpg', '2026-05-12 17:47:33'),
(190, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 18:05:24'),
(191, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 18:27:07'),
(192, 27, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 18:27:19'),
(193, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 18:28:00'),
(194, 42, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 19:17:25'),
(195, 42, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:17:25'),
(196, 42, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:17:26'),
(197, 42, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 19:17:27'),
(198, 42, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 19:17:36'),
(199, 42, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 19:17:56'),
(200, 42, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 19:18:05'),
(201, 42, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778613485880-06ee3be6-e3ff-4695-8653-c9e5d5de2ec1-IMG_20260501_034410.jpg', '2026-05-12 19:18:05'),
(202, 43, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 19:35:29'),
(203, 43, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 19:36:08'),
(204, 43, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 19:36:48'),
(205, 43, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 19:37:20'),
(206, 43, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 19:38:07'),
(207, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:38:07'),
(208, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:38:16'),
(209, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:38:53'),
(210, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:39:33'),
(211, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:40:14'),
(212, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 19:41:26'),
(213, 45, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 20:10:23'),
(214, 45, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 20:18:35'),
(215, 45, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 20:19:14'),
(216, 45, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 20:20:15'),
(217, 45, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 20:20:55'),
(218, 45, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-12 20:21:35'),
(219, 45, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 20:21:36'),
(220, 45, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 20:21:44'),
(221, 45, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 20:22:05'),
(222, 45, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 20:22:14'),
(223, 45, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 20:22:35'),
(224, 45, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 20:22:43'),
(225, 45, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778617378191-04a5cd1f-3dd5-48b6-babd-af0dec3a7c1d-IMG_20260501_034410.jpg', '2026-05-12 20:22:58'),
(226, 32, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 20:43:26'),
(227, 32, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 20:43:26'),
(228, 32, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 20:43:28'),
(229, 32, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 20:43:56'),
(230, 32, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 20:44:05'),
(231, 32, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 20:44:44'),
(232, 32, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778618694293-fab4eda3-3e5b-4bb0-a448-752435b4497f-IMG_20260501_034410.jpg', '2026-05-12 20:44:54'),
(233, 47, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 20:59:10'),
(234, 47, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 20:59:10'),
(235, 47, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-12 20:59:11'),
(236, 47, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 20:59:45'),
(237, 47, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 20:59:54'),
(238, 47, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-12 21:00:32'),
(239, 47, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 21:00:32'),
(240, 47, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-12 21:00:41'),
(241, 47, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778619670278-cd322394-b82c-4aa6-819e-9eef2d86ecb8-IMG_20260501_034410.jpg', '2026-05-12 21:01:10'),
(242, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 19:46:28'),
(243, 26, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-13 19:55:11'),
(244, 26, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-13 19:55:11'),
(245, 26, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-13 19:55:13'),
(246, 26, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-13 19:55:13'),
(247, 26, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 19:55:16'),
(248, 26, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 19:55:22'),
(249, 26, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778702125799-606aa124-ab48-487a-bdbf-2ef2e3766d1c-arabtrvl1527901963111.jpg', '2026-05-13 19:55:25'),
(250, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 20:02:31'),
(251, 27, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 20:02:31'),
(252, 22, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 20:02:40'),
(253, 21, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-13 20:02:48'),
(254, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-13 20:02:50'),
(255, 27, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 20:02:50'),
(256, 27, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778702578842-4f242655-80e1-4d01-b127-6566c8329e88-arabtrvl1527901963111.jpg', '2026-05-13 20:02:58'),
(257, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 20:10:25'),
(258, 25, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-13 20:10:25'),
(259, 22, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778703035485-12bfc0c1-2311-4c6f-8047-6dcec09a6e3f-arabtrvl1527901963111.jpg', '2026-05-13 20:10:35'),
(260, 25, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-13 20:11:29'),
(261, 25, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-13 20:11:29'),
(262, 25, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-13 20:11:33'),
(263, 25, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-13 20:11:40'),
(264, 25, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-13 20:11:40'),
(265, 25, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778703108777-4ae7acf4-f213-4316-9b75-9c6ac82967c9-arabtrvl1527901963111.jpg', '2026-05-13 20:11:48'),
(266, 46, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-14 05:18:25'),
(267, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 05:19:01'),
(268, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 05:19:25'),
(269, 46, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-14 06:01:06'),
(270, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 06:04:31'),
(271, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-14 07:12:57'),
(272, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 07:13:52'),
(273, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 07:22:05'),
(274, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 07:22:45'),
(275, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 07:25:21'),
(276, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-14 07:25:31'),
(277, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-14 07:25:45'),
(278, 24, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-14 07:25:56'),
(279, 35, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 07:26:04'),
(280, 48, 'assigned', 37.42199830, -122.08400000, NULL, '2026-05-14 08:23:05'),
(281, 48, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 08:23:35'),
(282, 48, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 08:23:44'),
(283, 48, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 08:24:22'),
(284, 48, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 08:25:02'),
(285, 48, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-14 08:25:32'),
(286, 48, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-14 08:25:41'),
(287, 48, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 08:26:02'),
(288, 48, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 08:26:11'),
(289, 48, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778747172939-4a1d262c-8f2b-41da-bca1-19206b9f01eb-aee30a5cabaf1e82cde205aa18e7c0e9a80416eb.jpg', '2026-05-14 08:26:12'),
(290, 46, 'assigned', 39.23725500, -123.15003170, NULL, '2026-05-14 22:08:51'),
(291, 46, 'at_pickup', 39.23725500, -123.15003170, NULL, '2026-05-14 22:08:54'),
(292, 46, 'at_pickup', 39.23725500, -123.15003170, NULL, '2026-05-14 22:08:56'),
(293, 46, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 22:09:40'),
(294, 46, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-14 22:09:40'),
(295, 46, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-14 22:10:01'),
(296, 46, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-14 22:10:33'),
(297, 46, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 22:10:33'),
(298, 46, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 22:10:40'),
(299, 46, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778796650283-5c3637fc-b8b4-42cd-8837-aaf47f577d8f-aee30a5cabaf1e82cde205aa18e7c0e9a80416eb.jpg', '2026-05-14 22:10:50'),
(300, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 22:11:40'),
(301, 43, 'at_pickup', 37.42199830, -122.08400000, NULL, '2026-05-14 22:12:43'),
(302, 43, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-14 22:12:45'),
(303, 43, 'en_route', 37.42199830, -122.08400000, NULL, '2026-05-14 22:12:46'),
(304, 43, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 22:13:15'),
(305, 43, 'at_dropoff', 37.42199830, -122.08400000, NULL, '2026-05-14 22:13:24'),
(306, 43, 'delivered', NULL, NULL, 'http://localhost:9190/darbak-uploads/epod/1778796811091-0ea3e228-fb1e-4989-936b-38d959831d45-trailers_ayuda_dana-1024x768.jpeg', '2026-05-14 22:13:31');

-- --------------------------------------------------------

--
-- بنية الجدول `trucks`
--

CREATE TABLE `trucks` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `plate_number` varchar(20) NOT NULL,
  `isthimara_no` text DEFAULT NULL,
  `truck_type` varchar(255) DEFAULT NULL,
  `category` varchar(64) NOT NULL DEFAULT 'legacy_unknown',
  `axle_count` tinyint(3) UNSIGNED NOT NULL DEFAULT 2,
  `body_type` varchar(64) NOT NULL DEFAULT 'standard_cargo',
  `payload_capacity` varchar(32) NOT NULL DEFAULT '5_10',
  `max_weight_tons` decimal(10,2) NOT NULL DEFAULT 7.50,
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
(2, 16, 'ص ر ي ١٢٣٤', '28786b32f5af63af0bc51c12c44a62e3', '', 0.00, 2026, '2027-04-28', 0, 'pending', '2026-04-29 19:15:32'),
(3, 17, '23123213', 'f6ae4cccdb8b3787188ec10b01a5388d', '', 0.00, 2026, '2027-04-28', 1, 'pending', '2026-04-29 19:41:43'),
(4, 16, '13123', 'b536a5393373d72cac9b91d1398064bc', 'دينا', 0.00, 2026, '2027-04-29', 1, 'pending', '2026-04-29 21:41:52'),
(5, 22, 'asdsad', 'c9d1a87afa62cbc7fdcd9cf8617bf4c4', '', 0.00, 2026, '2027-04-29', 1, 'pending', '2026-04-29 22:47:47'),
(6, 24, '1212 SDA', 'b8c309cf8732afcea285fbdcf782fd8f', '', 0.00, 2026, '2027-04-30', 1, 'pending', '2026-04-30 23:56:07'),
(7, 26, '1223ح ر ب', 'db5659f27217a0cdb6662ff79b175ede', '', 0.00, 2026, '2027-04-30', 1, 'pending', '2026-05-01 00:45:23'),
(8, 29, '13213 ASDASD', 'c4dfc86e9295f911e62afe606752d3c5', '', 0.00, 2026, '2027-05-01', 1, 'pending', '2026-05-02 12:57:16'),
(11, 36, '234234dfdsfd', 'f3aef4950cef9ccc33a9b91ce8f3dda5', '', 0.00, 2026, '2027-05-02', 1, 'pending', '2026-05-02 23:44:49'),
(12, 38, '234322sdfsd', 'ef1a71864ac0f031ac3d48a5fd2608ef', '', 0.00, 2026, '2027-05-03', 1, 'pending', '2026-05-04 00:43:38'),
(13, 24, 'ghjghfghfg24233', 'dbddf4a679fe3d7e4398d7654f6733d2', 'سطحة', 0.00, 2026, '2027-05-04', 0, 'pending', '2026-05-05 19:11:25'),
(14, 41, '112 dsa', '753f2c2bc828664da0b0bafea18136a9', '', 0.00, 2026, '2027-05-06', 1, 'pending', '2026-05-07 06:17:24'),
(15, 43, '32432', 'a277fc5609e50a6f6651b5f0c4e9317c', '', 0.00, 2026, '2027-05-06', 1, 'pending', '2026-05-07 07:56:02'),
(16, 41, '324234', '902c218b4fa9dd0f5bd379cf14547260', 'برادة', 0.00, 2026, '2027-05-06', 0, 'pending', '2026-05-07 08:12:09'),
(17, 46, 'a d f 15567', '5e63ce8afee02adee783bbcc14c66bd1', '', 0.00, 2026, '2027-05-11', 1, 'pending', '2026-05-12 19:24:30'),
(18, 55, 'ر ر ص 1267', 'eb81f02dfdeb669fb92436fe209a4ae1', '', 0.00, 2026, '2027-05-13', 1, 'pending', '2026-05-14 07:40:18');

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
  `profile_image_url` varchar(1000) DEFAULT NULL,
  `verification_status` enum('pending','verified','rejected') DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `issue_date` date DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `fcm_token` varchar(512) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- إرجاع أو استيراد بيانات الجدول `users`
--

INSERT INTO `users` (`id`, `full_name`, `email`, `phone`, `password`, `role`, `license_no`, `commercial_no`, `document_path`, `profile_image_url`, `verification_status`, `created_at`, `issue_date`, `expiry_date`, `fcm_token`, `is_active`) VALUES
(1, 'faris', NULL, '05', '$2a$10$DQ1iF3idtFCk6adc30aA3.iXYmcLeRrcenTbfr3w0cr7adaGLPuKe', 'shipper', NULL, '12001200', NULL, NULL, 'pending', '2026-03-31 19:47:48', NULL, NULL, NULL, 1),
(2, 'احمد', NULL, '054', '$2a$10$DX723dUr3xrljzjYbHSiD.ZlVLYZ8omNbZVIPkvBohLHnZFH3tqZy', 'driver', '12345678', NULL, NULL, NULL, 'pending', '2026-03-31 20:03:42', NULL, NULL, NULL, 1),
(3, 'Test Shipper', NULL, '0551000000', '$2a$10$qvvKaYHpH1jGwPMF3exaWOXduBdK8rTBWPB/g3tGbZno.KxmcDAeq', 'shipper', NULL, '56001234', NULL, NULL, 'pending', '2026-03-31 20:31:25', NULL, NULL, NULL, 1),
(4, 'Test Shipper2', 'testshipper2@darbak.com', '0551000001', '$2a$10$HjZGe1y9eL751TnlbXdJHe6u8pCWXRQ4jatCBc17cRomQQ5mnIp3G', 'shipper', NULL, '56001235', NULL, NULL, 'pending', '2026-03-31 20:33:57', NULL, NULL, NULL, 1),
(5, 'فارس محمد', 'db@gmail.com', '051', '$2a$10$1IHxHtF6KPYUJ0rIBmJ6reRXIzrQkHWELR4re6/xvc2TnwzROSIwS', 'driver', '145', NULL, NULL, NULL, 'pending', '2026-03-31 20:41:28', NULL, NULL, NULL, 1),
(6, 'وليد', 'wly@gmai.com', '057', '$2a$10$H/GRyyiE29GSOorZqn0cI.lYWKbSO.dZuZOjDLJJIVpx88AOzKuLm', 'driver', '555', NULL, NULL, NULL, 'pending', '2026-04-14 18:58:41', '2005-07-04', '2030-04-14', NULL, 1),
(7, 'تشفير', 'xr@gmail.com', '059', '$2a$10$dNayMRhBwqfdRORV1aB.2e.94fjfgrRUjfu1y8lm9Vm4azgMvSpoG', 'driver', '1128677570', NULL, NULL, NULL, 'pending', '2026-04-15 14:42:49', '2021-04-15', '2027-04-15', NULL, 1),
(8, 'اختبار تشفير', 'hdh@gmail.com', '053', '$2a$10$qqdboI4hYIVzX/xWajmx.eybuls9zxLzHDlbUcpbOqu5IPGeLHSzC', 'driver', '6e47adf7ebc466cbebe0f7a107f57cbc', NULL, NULL, NULL, 'pending', '2026-04-15 15:18:10', '2020-04-15', '2030-04-15', NULL, 1),
(9, 'sz', 'bb@bb.com', '011', '$2a$10$bszVKXQIjurk69vqF6AUh.t1kcMCH180b1PXBhz/nMEEqHEvQ8CH6', 'shipper', NULL, '98ccc0e11df969d1816b6fa2c7085219', NULL, NULL, 'pending', '2026-04-15 17:59:17', NULL, NULL, NULL, 1),
(10, 'SSSF', 'SSFS@GMAIL.COM', '022', '$2a$10$0TJR84mrsnU61rngLR0SPeleVvxr.wCZxYN7J3jpDKUC8TUqNsaLK', 'driver', 'ce048382a0c2d863363315742d21dac1', NULL, NULL, NULL, 'pending', '2026-04-15 18:04:13', '2022-04-15', '2026-04-30', NULL, 1),
(11, 'حمد', 'svcwsd@gmail.com', '044', '$2a$10$qCb0SIWV.k9055au4urw5uuPYRNeUibsw7DwGzC1c5OCWAArm7Zge', 'driver', 'be3bd62e3560be68b4590f03eba38eb2', NULL, NULL, NULL, 'pending', '2026-04-29 14:34:47', '2030-04-29', '2031-04-29', NULL, 1),
(12, 'حمد', 'svcws445d@gmail.com', '44', '$2a$10$8zi5jAabZyVT2bTErhexluNBU6G2FE/e0EzI5Qcm4/Qy8k0P/KBU2', 'driver', 'be3bd62e3560be68b4590f03eba38eb2', NULL, NULL, NULL, 'pending', '2026-04-29 14:35:59', '2030-04-29', '2031-04-29', NULL, 1),
(13, 'حمد', 'ssdsd@gmail.com', '066', '$2a$10$8sqYt62fnwmzmLm6DB3FL.T46nj5m0JDdCNqNxD5MNi8P7aNkRdJi', 'driver', 'd91b6b17e711bd49f6f793fe945b2b3e', NULL, NULL, NULL, 'pending', '2026-04-29 14:47:09', '2026-04-02', '2033-04-29', NULL, 1),
(14, 'داود', 'xsdx@gmail.com', '099', '$2a$10$VnC2.zBVAfYS48CyHcSSE.k97t2a89jLN46ANwRwPJ7jK1.FP2PRG', 'driver', '1c266473bec8cc370b5530fff6e9f205', NULL, NULL, NULL, 'pending', '2026-04-29 15:03:22', '2024-04-29', '2034-04-19', NULL, 1),
(15, 'abdulrahim', 'abdo@gmail.com', '0540', '$2a$10$PC2K1uo9kLptltGK/hXt1uw.EFZzVS9Y/rCy1pl1VSJc7x/CBDLoO', 'shipper', NULL, '84ecd6564f979a5e6862ceb5b742e2b3', NULL, NULL, 'pending', '2026-04-29 19:10:29', NULL, NULL, NULL, 1),
(16, 'abdulrahimdr', 'abdoe@gmail.com', '05407', '$2a$10$TrRyWMq0fITPLHn/1UQwVeVKp7KMm5a.AWu/asaqXa.wD0ld7M0Se', 'driver', 'fccdea1bc58204165805663e1560468f', NULL, NULL, NULL, 'pending', '2026-04-29 19:15:32', '2026-04-14', '2026-04-30', NULL, 1),
(17, 'asdsad', 'asdsad@gmail.com', '1111', '$2a$10$tNH4JwLQYgRKO4ZVT0ism.yyk6O3w3UvzylDggfJhJls1U0Um3C86', 'admin', '68be90c0c652c39fa4351d8fdc99dac7', NULL, NULL, NULL, 'pending', '2026-04-29 19:41:43', '2026-04-20', '2026-04-30', NULL, 1),
(18, 'غعلا', 'easfdsdf@gmail.com', '04678', '$2a$10$nAuwP3Ta9FYAStVryYvN5u3SLBR90b1j.yirr3k5SxOA/J3Xk4K8W', 'shipper', NULL, 'd7cbd6ee1536f23934fb81198e472579feea954e582980d5f51cac1f60acc474', 'commercial_docs/1777499336474-IMG_20260423_140242.jpg', NULL, 'pending', '2026-04-29 21:48:56', NULL, '2099-12-31', NULL, 1),
(19, 'sfsdfsdsdfds', 'dsfdsf@gmail.com', '234324', '$2a$10$CTZDx0MWKNjcHReb4Nyj3.ZnzXiYxBBudXG3mqad4uecihKzTNH9y', 'shipper', NULL, '7cde99609fbe10782900930716578a23', 'commercial_docs/1777500650306-35.pdf', NULL, 'pending', '2026-04-29 22:10:50', NULL, '2099-12-31', NULL, 1),
(20, 'sdfsd', 'sdfsdf@gmail.com', '0987', '$2a$10$cFKgQEpPWqvZew3uS3vrS.VvY5Lw63D1/iUB18HG/UckebuPJXqI.', 'shipper', NULL, 'c4b8de3da4d651713749e8e3ef73e082', 'commercial_docs/1777500934038-IMG_20260423_140242.jpg', NULL, 'pending', '2026-04-29 22:15:34', NULL, '2099-12-31', NULL, 1),
(21, 'dsdfsd', 'hfggfhfg@gmail.com', '324324', '$2a$10$CldmnnfQSOzXXUIjFculYepvr8ZONDWBbSBHOPhDQlTw5.ObFZKcy', 'shipper', NULL, 'cebdb04b51b776e925f6ccf1c0c4766f', 'commercial_docs/1777502113477-IMG_20260423_140242.jpg', NULL, 'verified', '2026-04-29 22:35:13', NULL, '2099-12-31', NULL, 1),
(22, 'sdfdsf', 'sdfjjdsfs@gmail.com', '234367', '$2a$10$A3f0B3UVsKvZptWQyvGsG..NfW7g/4M/aqfNT.RmGkMixAba1N9UO', 'driver', 'a2e9a4bd29546130703fb1bcc7d517d6', NULL, 'licenses/1777502867757-35.pdf', NULL, 'verified', '2026-04-29 22:47:47', '2026-04-08', '2026-04-30', NULL, 1),
(23, 'sdfdsfs', 'asdsadhtgf@gmail.com', '5765', '$2a$10$7QKNXQGXjOFsc1IABEBQTevXkcS217OBUCOigmpFVxDYw2K//XhG.', 'shipper', NULL, '2a0f1b1d25eeee491506922c14bb7a49', 'commercial_docs/1777502962834-IMG_20260423_140242.jpg', NULL, 'verified', '2026-04-29 22:49:22', NULL, '2099-12-31', NULL, 1),
(24, 'حسين', 'aada@gmail.com', '0582964532', '$2a$10$bloxQgfvDTUn5mkQp.ZDguBztVmHSDf.yKgJIojuJ3C87b4DPjKSa', 'driver', '3764e234eb3b3018acc8bcc0d6378f10', NULL, 'licenses/1777593367673-IMG_20260423_140242.jpg', 'profile/24/1778563510495.jpg', 'verified', '2026-04-30 23:56:07', '2026-05-01', '2026-05-16', NULL, 1),
(25, 'فارس', 'adadff@gmail.com', '0988', '$2a$10$OsWxiMYD.KkmCGRj/aOaZ.AOpjA8wvkrvY0TArKyjFEwzTw4Sd8Hq', 'shipper', NULL, 'c1c40284475f0bf54936376326d37321', 'commercial_docs/1777593424418-35.pdf', NULL, 'verified', '2026-04-30 23:57:04', NULL, '2099-12-31', NULL, 0),
(26, 'رازن البشري', 'rwezn@gmail.com', '4567', '$2a$10$x4NP9ZkbeW/28dKzmP0GIu6Ye4Eqim4Iy/z3HGgqChuBSB/kZLLya', 'driver', '6eaff8a05ae25ca1d29449c0fa52d0a8', NULL, 'licenses/1777596323268-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-01 00:45:23', '2026-05-01', '2026-05-30', NULL, 1),
(27, 'عبدالرحيم', 'aaa1@gmail.com', '0986', '$2a$10$ubQ/aWgP2NfFiODNOQdjrO3z7qPLtQR2DHjwVLgoQ6rItxCCFcx36', 'shipper', NULL, 'adb09f340d3f3eae344096eb0e6cdb75', 'commercial_docs/1777596437952-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-01 00:47:18', NULL, '2099-12-31', NULL, 1),
(28, 'عبدالله', 'aa@gmail.com', '052', '$2a$10$Himelkw9uQvPh5dxWpAaTuhGtnqGyGOaCpaQJzlNrsIHA0mEGH1qK', 'shipper', NULL, '7d407ab7815b4b1dbe9494fd6bb5d354', 'commercial_docs/1777726450666-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-02 12:54:10', NULL, '2099-12-31', NULL, 1),
(29, 'محمد', 'muhamed@gmail.com', '05111', '$2a$10$KS1M4E4dhFe8gK9uE1ewauq6mbFQzhWI3o3byrkUAGzxK/VnnrSIy', 'driver', '2c76a3db974e844d2f82250c5511217d', NULL, 'licenses/1777726636357-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-02 12:57:16', '2026-05-01', '2026-05-02', NULL, 1),
(30, 'FHFGHGF', 'frft@gmail.com', '787878', '$2a$10$t.gNynG06xJW1QMWLQa8oORRMsOC0lDxzJ1N0Hc4qJQilvCVsun2K', 'shipper', NULL, 'fd7555ca667a672b2d51c8d335b87f13', 'commercial_docs/1777749756237-IMG_20260501_034410.jpg', NULL, 'rejected', '2026-05-02 19:22:36', NULL, '2099-12-31', NULL, 1),
(31, 'ERRFDG', 'dfgfd@gmail.com', '34534534', '$2a$10$XOosPEsXfn0qMOkmL2pyy.MstVYhoB7k0r57mtAjBOXSBFFt9jVge', 'shipper', NULL, 'fd110fa9663aa545576ab08037263111', 'commercial_docs/1777749799884-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-02 19:23:19', NULL, '2099-12-31', NULL, 1),
(32, 'wadadwaadsada', 'sadsad@gmail.com', '234324275', '$2a$10$n8CIGHBZc/OclO1dhUIx5.510kumXE3tsxTXPMsQvubfg9I0cQFG6', 'shipper', NULL, '14177f5331064401faf71db4ade5ccfb', 'commercial_docs/1777763663255-IMG_20260503_021356.jpg', NULL, 'rejected', '2026-05-02 23:14:23', NULL, '2099-12-31', NULL, 1),
(33, 'adasda', 'sadad@gmail.com', '3242343242', '$2a$10$SLqb.dkvzNIa5.wYUADNdOVuoHDdn3.fgLlsUh6DqR4HRm1q.CsTO', 'shipper', NULL, 'f614fd96d594462b072c48515d958861', 'commercial_docs/1777764565840-IMG_20260503_021356.jpg', NULL, 'rejected', '2026-05-02 23:29:25', NULL, '2099-12-31', NULL, 1),
(36, 'asdsasd', 'asdsaddsadg@gmail.com', '2432424', '$2a$10$ksKNX/sjyngaaGlIgTAH5OLBxREPjBMipPv9jxpHWvjc90Oa8MevO', 'driver', '8a37539f1c279b40899dd9b3bcf6d0c1', NULL, 'licenses/1777765488950-IMG_20260503_021356.jpg', NULL, 'rejected', '2026-05-02 23:44:49', '2026-05-03', '2026-05-12', NULL, 1),
(37, 'ASDSADASD', 'asdasdadsarhgtrh@gmail.com', '345435', '$2a$10$EMQkKIPmDWpQpYRhyzGEhuHAqsfmg6jrKwc/ocYM/NjPAqZDd.kGe', 'shipper', NULL, '9babe0cb0cc2214d09bc8eeeb67e5d93', 'commercial_docs/1777855147604-IMG_20260503_021356.jpg', NULL, 'pending', '2026-05-04 00:39:07', NULL, '2099-12-31', NULL, 1),
(38, 'awdad', 'esedfsdf@gmail.com', '3453454334', '$2a$10$qsNV2QdqSRbYZcd6SqDNYOV0tkUWmTggXKo4oMGE4Vw8C4s8wqFPK', 'driver', '9babe0cb0cc2214d09bc8eeeb67e5d93', NULL, 'licenses/1777855418805-IMG_20260503_021356.jpg', NULL, 'pending', '2026-05-04 00:43:38', '2026-05-04', '2026-05-29', NULL, 0),
(39, 'sadsad', 'asdsa@gmail.com', '122344', '$2a$10$1wcQZfE2dZgkRBJCGF7FN.VOvWFm1l.z3EdoRv4DckwFvs.2FqtcS', 'shipper', NULL, 'aab6671552b94201a77f89b867cb0edd', 'commercial_docs/1778007333835-IMG_20260503_021356.jpg', NULL, 'pending', '2026-05-05 18:55:33', NULL, '2099-12-31', NULL, 1),
(40, 'محمد', 'mmeeq@gmail.com', '0540704419', '$2a$10$XES0LW7vCVPPNByhN28XLeOZ01voEe73UVoOggDAzv5QfwaS43in.', 'shipper', NULL, '871b89a485fb55a5c02b104e0245265c', 'commercial_docs/1778134551474-IMG_20260501_034410.jpg', 'profile/40/1778564439761.jpg', 'verified', '2026-05-07 06:15:51', NULL, '2099-12-31', NULL, 1),
(41, 'ناصر', 'naser@gmail.com', '0582678665', '$2a$10$gku1yg5EElM9tWE9rq4H7.7A9jqBFIaakG.Hyj8.OX4kUV97wHoVq', 'driver', '52bce5d54e2e7176d73b375da7588e28', NULL, 'licenses/1778134644406-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-07 06:17:24', '2026-05-01', '2026-05-30', NULL, 1),
(42, 'علي مزروعي', 'adasdsa@gmail.com', '0546789098', '$2a$10$QNcMJLuLwOm7DXX2s9FMH.Dbr46c1hqrV/8tQEIufgf/tYr9wtPyu', 'shipper', NULL, '96615b55b9e794818daa085a33dab689', 'commercial_docs/1778140090481-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-07 07:48:10', NULL, '2099-12-31', NULL, 1),
(43, 'احمد الحربي', 'asdsssdshjjjkkad@gmail.com', '05432344634534', '$2a$10$u2bS4nP8b1Yd40LOU1U3JumZzs.3ybcelAHr3B5ZG8CE.jA3E9xDi', 'driver', 'a6aeb4f27b9a732c2d94d515b7b2d7e8', NULL, 'licenses/1778140562920-IMG_20260501_034410.jpg', NULL, 'pending', '2026-05-07 07:56:02', '2026-05-07', '2026-05-29', NULL, 1),
(44, 'محمد الصبحي', 'asdasd@gmail.com', '0587768760', '$2a$10$evtiGGVB/Ck7G7926sMCjOj9M2qNYbmGpXssj4.xLE0r5XQQ2oEw2', 'shipper', NULL, 'b308fdcd60d22d068078e100d4c79264', 'commercial_docs/1778140777157-35.pdf', NULL, 'pending', '2026-05-07 07:59:37', NULL, '2099-12-31', NULL, 1),
(45, 'عبدالرحيم', '66@ddf', '0977', '$2a$10$6eUr5xXGwqCd0fjCzf.5M.KfXUhP.iLurxhkli23wNOezDZHgIxNm', 'shipper', NULL, 'a9c656f5c48a93a5e851112198aa47bd', 'commercial_docs/1778523283453-18ed4aad-af0b-4c3d-aec9-2da2a8ce289c-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-11 18:14:43', NULL, '2099-12-31', NULL, 1),
(46, 'انس', 'anas@gmail.com', '0567896673', '$2a$10$1L1HjG9KgoefNBlTNEUFIeJy4RW9w9vf/dNaG4NGfFaFkPy7Y3sE2', 'driver', '5ca89b93b2981792a2a1ee49169334c5', NULL, 'licenses/1778613870888-d5fb01a5-f092-45dd-94b7-0f138b6db85c-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-12 19:24:30', '2026-05-13', '2027-05-12', NULL, 1),
(47, 'مروان', 'marwan@gmail.com', '1234', '$2a$10$MPH/Fkz8gJV9MBUm0tn5hOborXmIW8KWA6DAesqxXw4cEcJ5zGuty', 'shipper', NULL, '45581be6ec343b2028c0c9ed2e183be2', 'commercial_docs/1778613925625-e3b0aa42-043b-4ae1-969c-8db5266e7800-IMG_20260501_034410.jpg', NULL, 'verified', '2026-05-12 19:25:25', NULL, '2099-12-31', NULL, 1),
(48, 'sdfsdf', 'sdfds@gmail.com', '545645', '$2a$10$Kefak9p/2./Yrry7nFwaFukMCTEd.5cyBPF8X/fFhf6wF8jwRsmFa', 'shipper', NULL, 'e07a03d89270169fbe1f1135f9c66931', 'commercial_docs/1778632908664-8ce00154-cf8e-4446-a67b-0b0885b044e7-acce5ebd-a0f8-4ca6-9962-76c6db725ef4.jpg', NULL, 'pending', '2026-05-13 00:41:48', NULL, '2099-12-31', NULL, 1),
(50, 'dsfdsf', 'd7om9g@gmail.com', '233332', '$2a$10$g2kQDUJWTOP6YZY8ZxZzuOM6AQCRotjPd0Dv2xHxX0UDDD.Z5kNZi', 'shipper', NULL, '2305a016392a72aff57a3b48e183f31a', 'commercial_docs/1778720958421-1eabd6e3-4ffd-4b16-847d-89630ca81348-IMG_20260501_034410.jpg', NULL, 'pending', '2026-05-14 01:09:18', NULL, '2099-12-31', NULL, 1),
(51, 'sdfdsf', 'sefesfesfefesf@gmail.com', '35435435', '$2a$10$Zhy5OYeZDcoYdt/Oji/D4e2FqSQdMdSkQyQGDhCdX9lpCM1CoJB5K', 'shipper', NULL, '13898e45929c4c96929849b92f65c533', 'commercial_docs/1778721118903-f67a0997-8610-4221-a01a-8344f20fa90b-IMG_20260501_034410.jpg', NULL, 'pending', '2026-05-14 01:11:59', NULL, '2099-12-31', NULL, 1),
(52, 'كيو', 'abdulrahim.11r@gmail.com', '987686867', '$2a$12$A5ljl5uge4o.DIhTLtVvcOXkHH9H4S/8ChHOKZcjqPCwzXKg6IBHy', 'shipper', NULL, 'c0438d16f5029a0a5942fee4b8c405f2', 'commercial_docs/1778722091751-bafaeb03-43c2-4b84-ac69-852bc7f1fd9b-IMG_20260501_034410.jpg', 'profile/52/1778744165771.jpg', 'verified', '2026-05-14 01:28:11', NULL, '2099-12-31', NULL, 1),
(53, 'dsadsad', 'abo.klood911@gmail.com', '23423432', '$2a$10$CUvKRUkpqxMmSJQB4cXCIeS2SUK2JaYEcyltNLUlRH//Ja.ouV.Cq', 'shipper', NULL, 'fb224b221076b1d4fcf374baa9e6960d', 'commercial_docs/1778722881830-a6827142-534e-4b96-953c-353070437fcf-IMG_20260501_034410.jpg', NULL, 'pending', '2026-05-14 01:41:21', NULL, '2099-12-31', NULL, 1),
(54, 'Abdulrahim', 'd7om9@gmail.com', '05667', '$2a$10$UqBJ3KdZpppzmgZEeKrRLuoSB737AImESTsv6Ggzpw48Q1cOA.mIu', 'shipper', NULL, '109483ec1d8a7924c51a7b5caa467458', 'commercial_docs/1778734541350-1bd9f7e7-dad5-4119-9255-d466e8711641-IMG_20260501_034410.jpg', NULL, 'pending', '2026-05-14 04:55:41', NULL, '2099-12-31', NULL, 1),
(55, 'علي محمود', 'abo.klod911@gmail.com', '0998767', '$2a$10$cGQ7k7mbwefOHW3U8IPcbu5j8L2z419U3gU6mu6UAjQoiKWSyK2aS', 'driver', '56e0897d3a977b68b67cf7a40be6defd', NULL, 'licenses/1778744418044-da139bc3-ec51-4380-9d16-63b58e561c75-images.jpeg', 'profile/55/1778744533630.jpg', 'verified', '2026-05-14 07:40:18', '2026-05-31', '2027-05-27', NULL, 1);

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
(20, 20, 0.00, 0.00, '2026-04-29 22:15:34'),
(21, 21, 0.00, 0.00, '2026-04-29 22:35:13'),
(22, 22, 0.00, 0.00, '2026-04-29 22:47:47'),
(23, 23, 0.00, 0.00, '2026-04-29 22:49:22'),
(24, 24, 1057966.00, 0.00, '2026-05-13 20:11:48'),
(25, 25, 0.00, 0.00, '2026-04-30 23:57:04'),
(26, 26, 0.00, 0.00, '2026-05-01 00:45:23'),
(27, 27, 0.00, 0.00, '2026-05-01 00:47:18'),
(28, 28, 0.00, 0.00, '2026-05-02 12:54:10'),
(29, 29, 0.00, 0.00, '2026-05-02 12:57:16'),
(30, 30, 0.00, 0.00, '2026-05-02 19:22:36'),
(31, 31, 0.00, 0.00, '2026-05-02 19:23:19'),
(32, 32, 0.00, 0.00, '2026-05-02 23:14:23'),
(33, 33, 0.00, 0.00, '2026-05-02 23:29:25'),
(36, 36, 0.00, 0.00, '2026-05-02 23:44:49'),
(37, 37, 0.00, 0.00, '2026-05-04 00:39:07'),
(38, 38, 0.00, 0.00, '2026-05-04 00:43:38'),
(39, 39, 0.00, 0.00, '2026-05-05 18:55:33'),
(40, 40, 0.00, 0.00, '2026-05-07 06:15:51'),
(41, 41, 9267.00, 0.00, '2026-05-12 21:01:10'),
(42, 42, 0.00, 0.00, '2026-05-07 07:48:10'),
(43, 43, 0.00, 0.00, '2026-05-07 07:56:02'),
(44, 44, 0.00, 0.00, '2026-05-07 07:59:37'),
(45, 45, 0.00, 0.00, '2026-05-11 18:14:43'),
(46, 46, 2920.00, 0.00, '2026-05-14 22:13:31'),
(47, 47, 0.00, 0.00, '2026-05-12 19:25:25'),
(48, 48, 0.00, 0.00, '2026-05-13 00:41:48'),
(50, 50, 0.00, 0.00, '2026-05-14 01:09:18'),
(51, 51, 0.00, 0.00, '2026-05-14 01:11:59'),
(52, 52, 0.00, 0.00, '2026-05-14 01:28:11'),
(53, 53, 0.00, 0.00, '2026-05-14 01:41:21'),
(54, 54, 0.00, 0.00, '2026-05-14 04:55:41'),
(55, 55, 1530.00, 0.00, '2026-05-14 08:26:12');

-- --------------------------------------------------------

--
-- بنية الجدول `wallet_transactions`
--

CREATE TABLE `wallet_transactions` (
  `id` int(11) NOT NULL,
  `wallet_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `type` enum('earnings','penalty','payout','adjustment') DEFAULT 'adjustment',
  `reference_id` int(11) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin_notification_reads`
--
ALTER TABLE `admin_notification_reads`
  ADD PRIMARY KEY (`notification_key`);

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
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_truck_id` (`truck_id`),
  ADD KEY `idx_truck_document_type` (`truck_id`,`document_type`);

--
-- Indexes for table `contracts`
--
ALTER TABLE `contracts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_contract_shipment` (`shipment_id`),
  ADD KEY `idx_contracts_bid` (`bid_id`),
  ADD KEY `fk_contracts_driver` (`driver_id`),
  ADD KEY `fk_contracts_shipper` (`shipper_id`);

--
-- Indexes for table `disputes`
--
ALTER TABLE `disputes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_disputes_status` (`status`),
  ADD KEY `idx_disputes_created` (`created_at`);

--
-- Indexes for table `messages`
--
ALTER TABLE `messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `shipment_id` (`shipment_id`),
  ADD KEY `sender_id` (`sender_id`),
  ADD KEY `receiver_id` (`receiver_id`),
  ADD KEY `idx_messages_receiver_delivered` (`receiver_id`,`delivered_at`),
  ADD KEY `idx_messages_receiver_read` (`receiver_id`,`read_at`),
  ADD KEY `idx_messages_shipment_receiver_read` (`shipment_id`,`receiver_id`,`read_at`),
  ADD KEY `idx_messages_type_created` (`message_type`,`created_at`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `idx_notifications_user_shipment_created` (`user_id`,`related_shipment_id`,`created_at`);

--
-- Indexes for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_password_reset_token_hash` (`token_hash`),
  ADD KEY `idx_password_reset_user_created` (`user_id`,`created_at`),
  ADD KEY `idx_password_reset_expires` (`expires_at`);

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
-- Indexes for table `wallet_transactions`
--
ALTER TABLE `wallet_transactions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `wallet_id` (`wallet_id`),
  ADD KEY `idx_wallet_tx_user` (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `bids`
--
ALTER TABLE `bids`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=55;

--
-- AUTO_INCREMENT for table `compliance_documents`
--
ALTER TABLE `compliance_documents`
  MODIFY `document_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT for table `contracts`
--
ALTER TABLE `contracts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `disputes`
--
ALTER TABLE `disputes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `messages`
--
ALTER TABLE `messages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=79;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=130;

--
-- AUTO_INCREMENT for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `ratings`
--
ALTER TABLE `ratings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `shipments`
--
ALTER TABLE `shipments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=50;

--
-- AUTO_INCREMENT for table `shipment_status_history`
--
ALTER TABLE `shipment_status_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=307;

--
-- AUTO_INCREMENT for table `trucks`
--
ALTER TABLE `trucks`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=56;

--
-- AUTO_INCREMENT for table `wallets`
--
ALTER TABLE `wallets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=56;

--
-- AUTO_INCREMENT for table `wallet_transactions`
--
ALTER TABLE `wallet_transactions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

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
  ADD CONSTRAINT `compliance_documents_truck_fk` FOREIGN KEY (`truck_id`) REFERENCES `trucks` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_comp_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- قيود الجداول `contracts`
--
ALTER TABLE `contracts`
  ADD CONSTRAINT `fk_contracts_bid` FOREIGN KEY (`bid_id`) REFERENCES `bids` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_contracts_driver` FOREIGN KEY (`driver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_contracts_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipments` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_contracts_shipper` FOREIGN KEY (`shipper_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

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
-- قيود الجداول `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD CONSTRAINT `password_reset_tokens_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

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

--
-- قيود الجداول `wallet_transactions`
--
ALTER TABLE `wallet_transactions`
  ADD CONSTRAINT `wallet_transactions_ibfk_1` FOREIGN KEY (`wallet_id`) REFERENCES `wallets` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `wallet_transactions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
