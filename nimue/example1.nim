on doThang appName, argument, arg2, arg3
    output "It works!"
    output " sometimes... "
    output appName
    output argument
    output arg3
    put "message:" && "foo" into fooLocalVar
    output fooLocalVar
end doThang

on main
    local myLocalVar
    doThang "Hello, world!", 1, 42.5
    put 1 + 2 * 3 - 4 * 5 into otherVar
    output otherVar
end main
