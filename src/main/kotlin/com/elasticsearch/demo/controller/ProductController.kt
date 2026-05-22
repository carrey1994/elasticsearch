package com.elasticsearch.demo.controller

import com.elasticsearch.demo.dto.CreateProductRequest
import com.elasticsearch.demo.dto.ProductResponse
import com.elasticsearch.demo.service.ProductService
import jakarta.validation.Valid
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/products")
class ProductController(
	private val productService: ProductService,
) {
	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	fun create(@Valid @RequestBody request: CreateProductRequest): ProductResponse =
		productService.create(request)

	@GetMapping
	fun search(@RequestParam("q") keyword: String): List<ProductResponse> =
		productService.search(keyword)

	@GetMapping("search")
	fun page(@RequestParam("q") keyword: String, pageable: Pageable): Page<ProductResponse> =
		productService.page(keyword, pageable)
}
