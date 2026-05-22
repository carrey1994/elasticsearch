package com.elasticsearch.demo.dto

import com.elasticsearch.demo.model.Product
import com.elasticsearch.demo.model.ProductDocument
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.math.BigDecimal
import java.time.Instant

data class CreateProductRequest(
	@field:NotBlank
	@field:Size(max = 255)
	val name: String,

	@field:NotBlank
	@field:Size(max = 2000)
	val description: String,

	@field:DecimalMin("0.0")
	val price: BigDecimal,
)

data class ProductResponse(
	val id: Long,
	val name: String,
	val description: String,
	val price: BigDecimal,
	val createdAt: Instant,
) {
	companion object {
		fun from(product: Product) =
			ProductResponse(
				id = product.id!!,
				name = product.name,
				description = product.description,
				price = product.price,
				createdAt = product.createdAt,
			)

		fun from(document: ProductDocument) =
			ProductResponse(
				id = document.id,
				name = document.name,
				description = document.description,
				price = BigDecimal.valueOf(document.price),
				createdAt = document.createdAt,
			)
	}
}
