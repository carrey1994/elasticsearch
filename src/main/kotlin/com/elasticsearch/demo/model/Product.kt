package com.elasticsearch.demo.model

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.math.BigDecimal
import java.time.Instant

@Entity
@Table(name = "products")
class Product(
	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	var id: Long? = null,

	@Column(nullable = false)
	var name: String = "",

	@Column(nullable = false, length = 2000)
	var description: String = "",

	@Column(nullable = false, precision = 12, scale = 2)
	var price: BigDecimal = BigDecimal.ZERO,

	@Column(nullable = false)
	var createdAt: Instant = Instant.now(),
)
