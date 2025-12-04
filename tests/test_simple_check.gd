extends GutTest

# Простейший тест для проверки что GUT работает
func test_basic_math():
	assert_eq(2 + 2, 4, "2 + 2 должно быть 4")

func test_string():
	assert_eq("hello", "hello", "Строки должны совпадать")

func test_true():
	assert_true(true, "true должно быть true")

func test_false():
	assert_false(false, "false должно быть false")
