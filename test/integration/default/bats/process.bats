#!/usr/bin/env bats

@test "process nrpe should be running" {
    run pgrep nrpe
    [ "$status" -eq 0 ]
    [[ "$output" != "" ]]
}

@test "Nrpe should be listening " {
#    run sudo netstat -anp|grep nrpe
    run netstat -an
    [ "$status" -eq 0 ]
    [[ "$output" =~ "5666" ]]
}


