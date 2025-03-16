What are the top 5 brands by receipts scanned for most recent month?

		WITH cte AS
		(
		SELECT ri.brandCode , COUNT(*)
		FROM fact_receipts r
		JOIN fact_receipt_items_bridge ri ON r.oid = ri.oid
		WHERE
			ri.brandCode IS NOT NULL
		AND STRFTIME('%Y-%m',r.dateScanned) = (SELECT STRFTIME('%Y-%m', MAX(createDate)) FROM receipts)
		GROUP BY ri.brandCode
		ORDER BY COUNT(*) DESC
		LIMIT 5
		)
		SELECT * from cte;


How does the ranking of the top 5 brands by receipts scanned for the recent month compare to the ranking for the previous month?

		WITH curr_month AS
		(
		SELECT ri.brandCode, COUNT(*) as current_month_count
		FROM fact_receipts r
		JOIN fact_receipt_items_bridge ri ON r.oid = ri.oid
		WHERE
		     ri.brandCode IS NOT NULL
		 AND STRFTIME('%Y-%m', r.dateScanned) = STRFTIME('%Y-%m', (SELECT MAX(dateScanned) FROM receipts))
		GROUP BY ri.brandCode
		ORDER BY COUNT(*) DESC 
		LIMIT 5
		), 
		prev_month AS
		(
		SELECT ri.brandCode , COUNT(*) as previous_month_count
		FROM fact_receipts r
		JOIN fact_receipt_items_bridge ri ON r.oid = ri.oid
		JOIN curr_month cm ON cm.brandCode = ri.brandCode
		WHERE
		     ri.brandCode IS NOT NULL
		 AND STRFTIME('%Y-%m', r.dateScanned) = STRFTIME('%Y-%m', (SELECT MAX(dateScanned) FROM receipts) - INTERVAL '1 month') 
		GROUP BY ri.brandCode
		ORDER BY COUNT(*) DESC 
		LIMIT 5
		)
		SELECT 
		    cm.brandCode,
		    cm.current_month_count,
		    pm.previous_month_count,
		    RANK() OVER (ORDER BY cm.current_month_count DESC) as current_month_rank,
		    RANK() OVER (ORDER BY pm.previous_month_count DESC) as previous_month_rank
		FROM curr_month cm
		LEFT JOIN prev_month pm ON cm.brandCode = pm.brandCode;


When considering average spend from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?

		WITH SpendSums AS (
		    SELECT
		        SUM(CASE WHEN rewardsReceiptStatus = 'FINISHED' THEN CAST(totalSpent AS FLOAT) ELSE 0 END) AS accepted_sum,
		        SUM(CASE WHEN rewardsReceiptStatus = 'REJECTED' THEN CAST(totalSpent AS FLOAT) ELSE 0 END) AS rejected_sum,
		        COUNT(CASE WHEN rewardsReceiptStatus = 'FINISHED' THEN 1 ELSE NULL END) AS accepted_count,
		        COUNT(CASE WHEN rewardsReceiptStatus = 'REJECTED' THEN 1 ELSE NULL END) AS rejected_count
		    FROM fact_receipts
		)
		SELECT
		    accepted_sum / accepted_count AS avg_accepted_spend,  
		    rejected_sum / rejected_count AS avg_rejected_spend, 
		    CASE
		        WHEN accepted_sum / accepted_count > rejected_sum / rejected_count THEN 'Accepted'
		        WHEN rejected_sum / rejected_count > accepted_sum / accepted_count THEN 'Rejected'
		        ELSE 'Equal'
		    END AS greater_avg_spend
		FROM SpendSums;


When considering total number of items purchased from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?

		WITH items_counts AS (
		    SELECT
		        SUM(CASE WHEN rewardsReceiptStatus = 'FINISHED' THEN CAST(purchasedItemCount AS FLOAT) ELSE 0 END) AS accepted_items_counts,
		        SUM(CASE WHEN rewardsReceiptStatus = 'REJECTED' THEN CAST(purchasedItemCount AS FLOAT) ELSE 0 END) AS rejected_items_counts,
		    FROM fact_receipts
		)
		SELECT
		    accepted_items_counts,
		    rejected_items_counts,
		    CASE
		        WHEN accepted_items_counts > rejected_items_counts THEN 'Accepted'
		        WHEN accepted_items_counts < rejected_items_counts THEN 'Rejected'
		        ELSE 'Equal'
		    END AS greater_items_counts
		FROM items_counts;


Which brand has the most spend among users who were created within the past 6 months?

		WITH RecentUsers AS (
		    SELECT oid
		    FROM dim_user
		    WHERE CAST(createdDate AS DATE) >= CAST((SELECT MAX(dateScanned) FROM receipts) AS DATE) - INTERVAL '6 months'
		),
		BrandSpend AS (
		    SELECT 
		        ri.brandCode, 
		        SUM(CAST(ri.finalPrice AS FLOAT)) as total_spend
		    FROM fact_receipt_items_bridge ri
		    JOIN fact_receipts r ON ri.oid = r.oid  
		    JOIN RecentUsers ru ON r.userId = ru.oid
		    WHERE ri.brandCode IS NOT NULL
		    GROUP BY ri.brandCode
		)
		SELECT brandCode, total_spend
		FROM BrandSpend
		ORDER BY total_spend DESC
		LIMIT 1;

Which brand has the most transactions among users who were created within the past 6 months?

		WITH RecentUsers AS (
		    SELECT oid
		    FROM dim_user
		    WHERE CAST(createdDate AS DATE) >= CAST((SELECT MAX(dateScanned) FROM receipts) AS DATE) - INTERVAL '6 months'
		),
		BrandTransactions AS (
		    SELECT 
		        ri.brandCode, 
		        COUNT(*) as transaction_count
		    FROM fact_receipt_items_bridge ri
		    JOIN fact_receipts r ON ri.oid = r.oid  
		    JOIN RecentUsers ru ON r.userId = ru.oid
		    WHERE ri.brandCode IS NOT NULL
		    GROUP BY ri.brandCode
		)
		SELECT brandCode, transaction_count
		FROM BrandTransactions
		ORDER BY transaction_count DESC
		LIMIT 1;