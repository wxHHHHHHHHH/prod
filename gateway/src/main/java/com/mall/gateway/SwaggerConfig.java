package com.mall.gateway;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.config.ResourceHandlerRegistry;
import org.springframework.web.reactive.config.WebFluxConfigurer;

/**
 * Swagger UI 资源放行配置
 *
 * Gateway 是 WebFlux 反应式网关，不走传统 Spring MVC 的 Swagger。
 * 此处配置放行 Swagger UI 静态资源路径，避免被网关拦截。
 *
 * 各微服务自身的 Swagger UI 访问地址:
 *   auth-service:    http://localhost:8081/swagger-ui.html
 *   product-service: http://localhost:8083/swagger-ui.html
 *   order-service:   http://localhost:8084/swagger-ui.html
 *   payment-service: http://localhost:8085/swagger-ui.html
 */
@Configuration
public class SwaggerConfig implements WebFluxConfigurer {

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 放行 Swagger UI 相关静态资源
        registry.addResourceHandler("/swagger-ui/**")
            .addResourceLocations("classpath:/META-INF/resources/webjars/springdoc-openapi/");
    }
}
