package com.elasticsearch.demo.model

import org.springframework.data.annotation.Id
import org.springframework.data.elasticsearch.annotations.DateFormat
import org.springframework.data.elasticsearch.annotations.Document
import org.springframework.data.elasticsearch.annotations.Field
import org.springframework.data.elasticsearch.annotations.FieldType
import org.springframework.data.elasticsearch.annotations.InnerField
import org.springframework.data.elasticsearch.annotations.Mapping
import org.springframework.data.elasticsearch.annotations.MultiField
import org.springframework.data.elasticsearch.annotations.Setting
import java.time.Instant

@Document(indexName = "products", createIndex = true)
@Setting(settingPath = "elasticsearch/products-settings.json")
@Mapping(mappingPath = "elasticsearch/products-mappings.json")
data class ProductDocument(
	@Id
	val id: Long,

	@MultiField(
		mainField = Field(type = FieldType.Text, analyzer = "product_index", searchAnalyzer = "product_search"),
		otherFields = [InnerField(suffix = "keyword", type = FieldType.Keyword)]
	)
	val name: String,

	@Field(type = FieldType.Text, analyzer = "product_index", searchAnalyzer = "product_search")
	val description: String,

	@Field(type = FieldType.Double)
	val price: Double,

	@Field(type = FieldType.Date, format = [DateFormat.epoch_millis])
	val createdAt: Instant,
) {
	companion object {
		fun from(product: Product): ProductDocument =
			ProductDocument(
				id = product.id!!,
				name = product.name,
				description = product.description,
				price = product.price.toDouble(),
				createdAt = product.createdAt,
			)
	}
}
