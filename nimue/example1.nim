on doThang appName, argument, arg2, arg3
    output "It works!"
    output " sometimes... "
    output appName
    output argument
    output arg3
    put "foo" into fooLocalVar
    output fooLocalVar
end doThang

function main
    local myLocalVar
    doThang "Hello, world!", 1, 42.5
end main
